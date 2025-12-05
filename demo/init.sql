-- Expanso + LMCache Demo: Database Initialization
--
-- This creates a documents table that simulates a RAG knowledge base.
-- When documents are updated, Expanso CDC will detect the change
-- and trigger LMCache invalidation.

-- Create the documents table
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT DEFAULT 'general',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create an update trigger to auto-update the timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER documents_update_timestamp
    BEFORE UPDATE ON documents
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- Insert sample documents (simulating a company knowledge base)
INSERT INTO documents (title, content, category) VALUES
(
    'Vacation Policy',
    'All full-time employees are entitled to 15 paid vacation days per year. ' ||
    'Unused vacation days can be carried over to the next year, up to a maximum of 5 days. ' ||
    'Vacation requests must be submitted at least 2 weeks in advance.',
    'policy'
),
(
    'Remote Work Guidelines',
    'Employees may work remotely up to 2 days per week with manager approval. ' ||
    'Remote work requires a stable internet connection and a dedicated workspace. ' ||
    'All remote workers must be available during core hours (10am-4pm).',
    'policy'
),
(
    'Product Overview',
    'Our flagship product is an AI-powered analytics platform that helps ' ||
    'businesses make data-driven decisions. Key features include real-time ' ||
    'dashboards, predictive analytics, and automated reporting.',
    'product'
),
(
    'API Documentation',
    'The REST API supports JSON format. Authentication is via Bearer tokens. ' ||
    'Rate limits are 100 requests per minute for free tier, 1000 for premium. ' ||
    'All endpoints return standard HTTP status codes.',
    'technical'
),
(
    'Expense Reimbursement',
    'Business expenses must be submitted within 30 days of purchase. ' ||
    'Receipts are required for all expenses over $25. ' ||
    'Approved expenses are reimbursed within 2 pay periods.',
    'policy'
);

-- Create a publication for CDC (Change Data Capture)
-- This allows Expanso to stream changes from this table
CREATE PUBLICATION lmcache_pub FOR TABLE documents;

-- ============================================================
-- Token Pricing Table
-- ============================================================
-- "Token anxiety" is real - this tracks LLM pricing so we can
-- show cache savings. Updated monthly by Expanso pipeline.

CREATE TABLE token_pricing (
    id SERIAL PRIMARY KEY,
    model_id TEXT NOT NULL,
    name TEXT,
    input_cost_per_million DECIMAL(10,4),   -- $ per 1M input tokens
    output_cost_per_million DECIMAL(10,4),  -- $ per 1M output tokens
    context_length INTEGER,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert some baseline pricing (as of late 2024)
INSERT INTO token_pricing (model_id, name, input_cost_per_million, output_cost_per_million, context_length) VALUES
('gpt-4o', 'GPT-4o', 2.50, 10.00, 128000),
('gpt-4o-mini', 'GPT-4o Mini', 0.15, 0.60, 128000),
('claude-3-5-sonnet', 'Claude 3.5 Sonnet', 3.00, 15.00, 200000),
('claude-3-haiku', 'Claude 3 Haiku', 0.25, 1.25, 200000),
('llama-3.1-70b', 'Llama 3.1 70B', 0.52, 0.75, 131072),
('deepseek-v3', 'DeepSeek V3', 0.14, 0.28, 65536);

-- ============================================================
-- Cache Events Table
-- ============================================================
-- Track cache hits/misses to calculate savings
-- "For agent swarms doing parallel subtasks, this is dramatic"

CREATE TABLE cache_events (
    id SERIAL PRIMARY KEY,
    event_type TEXT NOT NULL,  -- 'hit' or 'miss'
    model_id TEXT,
    input_tokens INTEGER,
    output_tokens INTEGER,
    latency_ms INTEGER,
    saved_dollars DECIMAL(10,6),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert sample cache events for demo
INSERT INTO cache_events (event_type, model_id, input_tokens, output_tokens, latency_ms, saved_dollars) VALUES
('miss', 'claude-3-5-sonnet', 15000, 500, 2800, 0),
('hit', 'claude-3-5-sonnet', 15000, 450, 180, 0.045),
('hit', 'claude-3-5-sonnet', 15000, 480, 195, 0.045),
('hit', 'claude-3-5-sonnet', 15000, 520, 210, 0.045),
('miss', 'gpt-4o', 8000, 300, 3200, 0),
('hit', 'gpt-4o', 8000, 280, 150, 0.020),
('hit', 'gpt-4o', 8000, 310, 165, 0.020);

-- ============================================================
-- Cache Warmup Log
-- ============================================================
-- Tracks which documents have been pre-warmed to avoid duplicates
-- Used by expanso-cache-warmup.yaml pipeline

CREATE TABLE cache_warmup_log (
    id SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id),
    warmed_at TIMESTAMP DEFAULT NOW(),
    warmup_latency_ms INTEGER,
    status TEXT DEFAULT 'success'
);

CREATE INDEX idx_warmup_document ON cache_warmup_log(document_id);
CREATE INDEX idx_warmup_time ON cache_warmup_log(warmed_at);

-- ============================================================
-- Test Results Table
-- ============================================================
-- Stores aggregated test results from kv-cache-tester
-- Populated by expanso-results-aggregator.yaml pipeline

CREATE TABLE test_results (
    id SERIAL PRIMARY KEY,
    backend TEXT,
    context_size INTEGER,
    cache_hit_rate DECIMAL(5,2),
    avg_ttft_ms DECIMAL(10,2),
    throughput DECIMAL(10,2),
    cost_per_request DECIMAL(12,8),
    savings_per_request DECIMAL(12,8),
    monthly_savings DECIMAL(10,2),
    performance_score DECIMAL(6,4),
    source_file TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_results_backend ON test_results(backend);
CREATE INDEX idx_results_cache ON test_results(cache_hit_rate);

-- Verify setup
DO $$
BEGIN
    RAISE NOTICE 'Database initialized successfully!';
    RAISE NOTICE 'Documents table created with % rows', (SELECT COUNT(*) FROM documents);
    RAISE NOTICE 'Token pricing table created with % models', (SELECT COUNT(*) FROM token_pricing);
    RAISE NOTICE 'Cache events table created with % events', (SELECT COUNT(*) FROM cache_events);
    RAISE NOTICE 'Cache warmup log table created';
    RAISE NOTICE 'Test results table created';
    RAISE NOTICE 'CDC publication "lmcache_pub" created';
END $$;
