#!/usr/bin/env python3
"""
LMCache Mock API Server

This simulates the LMCache controller API for demo purposes.
In production, you would use the real LMCache API server.

Endpoints:
  POST /clear     - Clear cache (called by Expanso on data changes)
  POST /lookup    - Lookup cache status
  GET  /health    - Health check
  GET  /stats     - View invalidation statistics
  GET  /savings   - View token cost savings ("token anxiety" relief!)
"""

from fastapi import FastAPI, Request
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import uvicorn
import random

app = FastAPI(
    title="LMCache Mock API",
    description="Simulates LMCache controller for Expanso integration demo",
    version="1.0.0"
)

# Track invalidations for demo visibility
invalidation_log = []

# Track cache events for savings calculation
cache_events = []

# Token pricing (updated monthly by Expanso pipeline)
TOKEN_PRICING = {
    "gpt-4o": {"input": 2.50, "output": 10.00},
    "gpt-4o-mini": {"input": 0.15, "output": 0.60},
    "claude-3-5-sonnet": {"input": 3.00, "output": 15.00},
    "claude-3-haiku": {"input": 0.25, "output": 1.25},
    "llama-3.1-70b": {"input": 0.52, "output": 0.75},
    "deepseek-v3": {"input": 0.14, "output": 0.28},
}


class ClearRequest(BaseModel):
    instance_id: Optional[str] = "default"
    location: Optional[str] = "LocalCPUBackend"
    document_id: Optional[int] = None
    reason: Optional[str] = None


class ClearResponse(BaseModel):
    event_id: str
    num_tokens: int
    message: str


class LookupRequest(BaseModel):
    tokens: list[int] = []


class LookupResponse(BaseModel):
    event_id: str
    layout_info: dict


@app.post("/clear", response_model=ClearResponse)
async def clear_cache(request: ClearRequest):
    """
    Clear cache entries.

    Called by Expanso when document changes are detected.
    In production, this would actually clear LMCache entries.
    """
    event_id = f"Clear_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}"

    # Log the invalidation for demo visibility
    log_entry = {
        "event_id": event_id,
        "timestamp": datetime.now().isoformat(),
        "instance_id": request.instance_id,
        "location": request.location,
        "document_id": request.document_id,
        "reason": request.reason,
    }
    invalidation_log.append(log_entry)

    # Keep only last 100 entries
    if len(invalidation_log) > 100:
        invalidation_log.pop(0)

    print(f"[CACHE CLEAR] {log_entry}")

    return ClearResponse(
        event_id=event_id,
        num_tokens=256,  # Simulated token count
        message=f"Cache cleared for document {request.document_id}" if request.document_id else "Cache cleared"
    )


@app.post("/lookup", response_model=LookupResponse)
async def lookup_cache(request: LookupRequest):
    """
    Lookup cache status for given tokens.

    In production, this would query actual LMCache state.
    """
    event_id = f"Lookup_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}"

    # Simulate some cached tokens
    return LookupResponse(
        event_id=event_id,
        layout_info={
            "default_instance": ["LocalCPUBackend", len(request.tokens)]
        }
    )


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "lmcache-mock-api",
        "timestamp": datetime.now().isoformat()
    }


@app.get("/stats")
async def get_stats():
    """
    Get invalidation statistics.

    Useful for demo to show what's happening.
    """
    return {
        "total_invalidations": len(invalidation_log),
        "recent_invalidations": invalidation_log[-10:],  # Last 10
        "timestamp": datetime.now().isoformat()
    }


@app.get("/savings")
async def get_savings():
    """
    Calculate token cost savings from cache hits.

    This is the "token anxiety" relief dashboard!
    Shows how much money you're saving by caching.
    """
    # Simulate some cache events for demo
    if not cache_events:
        # Generate sample data showing typical agent workload
        models = ["claude-3-5-sonnet", "gpt-4o", "gpt-4o-mini"]
        for i in range(20):
            model = random.choice(models)
            is_hit = random.random() > 0.3  # 70% hit rate
            input_tokens = random.randint(5000, 20000)
            pricing = TOKEN_PRICING.get(model, {"input": 1.0})

            cache_events.append({
                "event_type": "hit" if is_hit else "miss",
                "model": model,
                "input_tokens": input_tokens,
                "latency_ms": random.randint(100, 300) if is_hit else random.randint(2000, 4000),
                "saved_dollars": (input_tokens / 1_000_000) * pricing["input"] if is_hit else 0,
                "timestamp": datetime.now().isoformat()
            })

    # Calculate totals
    total_hits = sum(1 for e in cache_events if e["event_type"] == "hit")
    total_misses = sum(1 for e in cache_events if e["event_type"] == "miss")
    total_saved = sum(e["saved_dollars"] for e in cache_events)

    avg_hit_latency = sum(e["latency_ms"] for e in cache_events if e["event_type"] == "hit") / max(total_hits, 1)
    avg_miss_latency = sum(e["latency_ms"] for e in cache_events if e["event_type"] == "miss") / max(total_misses, 1)

    # Project monthly savings (assuming 100k requests/month)
    hit_rate = total_hits / max(len(cache_events), 1)
    projected_monthly_requests = 100000
    avg_input_tokens = 12000
    avg_cost_per_million = 2.5  # Blended average
    projected_monthly_savings = (
        projected_monthly_requests * hit_rate * avg_input_tokens / 1_000_000 * avg_cost_per_million
    )

    return {
        "summary": {
            "total_requests": len(cache_events),
            "cache_hits": total_hits,
            "cache_misses": total_misses,
            "hit_rate_percent": round(hit_rate * 100, 1),
            "total_saved_dollars": round(total_saved, 4),
        },
        "latency": {
            "avg_hit_latency_ms": round(avg_hit_latency),
            "avg_miss_latency_ms": round(avg_miss_latency),
            "latency_improvement_percent": round((1 - avg_hit_latency / max(avg_miss_latency, 1)) * 100, 1),
        },
        "projections": {
            "monthly_requests": projected_monthly_requests,
            "projected_monthly_savings_dollars": round(projected_monthly_savings, 2),
            "note": "Based on current hit rate and average token usage"
        },
        "token_pricing": TOKEN_PRICING,
        "message": "Token anxiety? Cache hits = $0 input cost. This is the savings.",
        "timestamp": datetime.now().isoformat()
    }


@app.post("/simulate-traffic")
async def simulate_traffic(requests: int = 50):
    """
    Simulate agent traffic to populate savings dashboard.

    Use this to see the "agent swarm effect" - parallel
    subtasks hitting cache = dramatic savings.
    """
    models = ["claude-3-5-sonnet", "gpt-4o", "gpt-4o-mini", "llama-3.1-70b"]

    for i in range(requests):
        model = random.choice(models)
        is_hit = random.random() > 0.25  # 75% hit rate for demo
        input_tokens = random.randint(5000, 25000)
        pricing = TOKEN_PRICING.get(model, {"input": 1.0})

        cache_events.append({
            "event_type": "hit" if is_hit else "miss",
            "model": model,
            "input_tokens": input_tokens,
            "latency_ms": random.randint(80, 250) if is_hit else random.randint(1800, 4500),
            "saved_dollars": (input_tokens / 1_000_000) * pricing["input"] if is_hit else 0,
            "timestamp": datetime.now().isoformat()
        })

    # Keep only last 500 events
    if len(cache_events) > 500:
        cache_events[:] = cache_events[-500:]

    return {
        "simulated_requests": requests,
        "total_events": len(cache_events),
        "message": "Traffic simulated. Check /savings for the dashboard."
    }


# Store test results and backend comparisons
test_results = []
backend_comparisons = []


class TestResult(BaseModel):
    backend: Optional[str] = "default"
    context_size: Optional[int] = None
    cache_hit_rate: Optional[float] = None
    avg_ttft_ms: Optional[float] = None
    throughput: Optional[float] = None
    cost_per_request: Optional[float] = None
    savings_per_request: Optional[float] = None
    monthly_savings_100k: Optional[float] = None
    performance_score: Optional[float] = None
    rank_note: Optional[str] = None
    source_file: Optional[str] = None


@app.post("/results")
async def receive_results(result: TestResult):
    """
    Receive aggregated test results from Expanso pipeline.

    Called by expanso-results-aggregator.yaml when new
    test results are detected.
    """
    entry = {
        **result.dict(),
        "received_at": datetime.now().isoformat()
    }
    test_results.append(entry)

    # Keep only last 100
    if len(test_results) > 100:
        test_results.pop(0)

    print(f"[RESULTS] Received: cache_rate={result.cache_hit_rate}%, savings=${result.monthly_savings_100k}/month")

    return {"status": "received", "total_results": len(test_results)}


@app.get("/results")
async def get_results():
    """Get all aggregated test results."""
    return {
        "total_results": len(test_results),
        "results": test_results[-20:],  # Last 20
        "timestamp": datetime.now().isoformat()
    }


@app.post("/backend-comparison")
async def receive_backend_comparison(result: TestResult):
    """
    Receive backend comparison data from Expanso pipeline.

    Called by expanso-backend-comparison.yaml when comparing
    different cache backends (dynamo, lmcache, etc.)
    """
    entry = {
        **result.dict(),
        "received_at": datetime.now().isoformat()
    }
    backend_comparisons.append(entry)

    # Keep only last 200
    if len(backend_comparisons) > 200:
        backend_comparisons.pop(0)

    print(f"[COMPARISON] {result.backend}: score={result.performance_score} ({result.rank_note})")

    return {"status": "received", "total_comparisons": len(backend_comparisons)}


@app.get("/backend-comparison")
async def get_backend_comparison():
    """
    Get backend comparison summary.

    Shows which cache backend is winning for each context size.
    """
    # Group by context size and find winner
    from collections import defaultdict
    by_context = defaultdict(list)

    for comp in backend_comparisons:
        ctx = comp.get("context_size", 0)
        by_context[ctx].append(comp)

    winners = {}
    for ctx, comps in by_context.items():
        if comps:
            winner = min(comps, key=lambda x: x.get("performance_score", 999))
            winners[ctx] = {
                "winner": winner.get("backend"),
                "score": winner.get("performance_score"),
                "ttft_ms": winner.get("avg_ttft_ms"),
                "all_backends": [c.get("backend") for c in comps]
            }

    return {
        "total_comparisons": len(backend_comparisons),
        "winners_by_context": winners,
        "recent_comparisons": backend_comparisons[-10:],
        "timestamp": datetime.now().isoformat()
    }


@app.get("/")
async def root():
    """API documentation redirect."""
    return {
        "message": "LMCache Mock API",
        "docs": "/docs",
        "endpoints": {
            "POST /clear": "Clear cache entries (called by Expanso)",
            "POST /lookup": "Lookup cache status",
            "GET /health": "Health check",
            "GET /stats": "View invalidation statistics",
            "GET /savings": "View token cost savings dashboard",
            "POST /simulate-traffic": "Simulate agent traffic for demo",
            "GET /results": "View aggregated test results",
            "POST /results": "Receive test results (from Expanso)",
            "GET /backend-comparison": "View backend comparison summary",
            "POST /backend-comparison": "Receive backend comparison (from Expanso)"
        }
    }


if __name__ == "__main__":
    print("Starting LMCache Mock API on port 9000...")
    print("Docs available at: http://localhost:9000/docs")
    print("")
    print("Key endpoints:")
    print("  GET  /savings  - Token cost savings dashboard")
    print("  GET  /stats    - Cache invalidation stats")
    print("  POST /clear    - Clear cache (called by Expanso)")
    uvicorn.run(app, host="0.0.0.0", port=9000)
