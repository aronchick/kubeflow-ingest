#!/usr/bin/env bash
# ============================================================
# Expanso + LMCache Demo: Data-Driven Cache Invalidation
# ============================================================
#
# This demo shows how Expanso connects LMCache to your data,
# automatically invalidating cache when documents change.
#
# Usage: ./demo.sh
#
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

pause() {
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# ============================================================
# INTRO
# ============================================================
clear
print_header "Expanso + LMCache Demo"

echo -e "${BOLD}The Problem:${NC}"
print_info "You're building a RAG system. Documents are in a database."
print_info "When documents change, your LLM cache becomes STALE."
print_info "Users get WRONG ANSWERS from outdated context."
echo ""

echo -e "${BOLD}The Solution:${NC}"
print_info "Expanso connects LMCache to your data sources."
print_info "When data changes, cache is automatically invalidated."
print_info "20 lines of YAML replaces 500+ lines of custom code."

pause

# ============================================================
# STEP 1: Start Services
# ============================================================
print_header "Step 1: Starting Services"

print_step "Starting PostgreSQL, Redis, LMCache API, and Expanso..."
docker compose up -d

print_step "Waiting for services to be healthy..."
sleep 5

# Check services
if docker compose ps | grep -q "healthy"; then
    print_success "All services are running!"
else
    print_warning "Some services may still be starting..."
    sleep 5
fi

echo ""
print_info "Services running:"
docker compose ps --format "table {{.Name}}\t{{.Status}}"

pause

# ============================================================
# STEP 2: Show Current Data
# ============================================================
print_header "Step 2: Current Documents in Database"

print_step "Querying documents table..."
echo ""

docker compose exec -T postgres psql -U demo -d demo -c \
    "SELECT id, title, LEFT(content, 50) || '...' as content_preview FROM documents;"

echo ""
print_info "These documents would be used for RAG context."
print_info "If cached, queries about these would hit the cache."

pause

# ============================================================
# STEP 3: Show the Expanso Pipeline
# ============================================================
print_header "Step 3: The Expanso Pipeline (The Magic)"

print_step "Here's the entire pipeline that handles cache invalidation:"
echo ""

echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
cat expanso-pipeline.yaml | head -55
echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

echo ""
print_info "That's it! ~25 lines of YAML."
print_info "No custom code. No triggers. Just declarative YAML."

pause

# ============================================================
# STEP 4: Check Initial Cache State
# ============================================================
print_header "Step 4: Check LMCache Stats (Before)"

print_step "Current cache invalidation stats:"
echo ""

curl -s http://localhost:9000/stats | python3 -m json.tool 2>/dev/null || \
    curl -s http://localhost:9000/stats

echo ""
print_info "No invalidations yet - we haven't changed any data."

pause

# ============================================================
# STEP 5: Update a Document
# ============================================================
print_header "Step 5: Update a Document (Trigger Invalidation)"

print_step "Let's update the Vacation Policy document..."
echo ""

echo -e "${YELLOW}BEFORE:${NC}"
docker compose exec -T postgres psql -U demo -d demo -c \
    "SELECT title, LEFT(content, 60) || '...' as content FROM documents WHERE id = 1;"

echo ""
print_step "Updating vacation days from 15 to 25..."
echo ""

docker compose exec -T postgres psql -U demo -d demo -c \
    "UPDATE documents SET content = 'All full-time employees are entitled to 25 paid vacation days per year. Unused vacation days can be carried over to the next year, up to a maximum of 10 days. Vacation requests must be submitted at least 2 weeks in advance.' WHERE id = 1;"

echo ""
echo -e "${GREEN}AFTER:${NC}"
docker compose exec -T postgres psql -U demo -d demo -c \
    "SELECT title, LEFT(content, 60) || '...' as content FROM documents WHERE id = 1;"

pause

# ============================================================
# STEP 6: See Expanso React
# ============================================================
print_header "Step 6: Watch Expanso React (Real-Time)"

print_step "Expanso detected the change and called LMCache..."
echo ""

print_step "Expanso logs:"
echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"
docker compose logs --tail=20 expanso 2>&1 | grep -E "(Document changed|Operation|INFO)" | tail -10 || \
    docker compose logs --tail=10 expanso
echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"

pause

# ============================================================
# STEP 7: Verify Cache Invalidation
# ============================================================
print_header "Step 7: Verify Cache Was Invalidated"

print_step "LMCache received the invalidation request:"
echo ""

curl -s http://localhost:9000/stats | python3 -m json.tool 2>/dev/null || \
    curl -s http://localhost:9000/stats

echo ""
print_success "Cache invalidation was triggered automatically!"
print_info "In a real system, the next query would fetch fresh data."

pause

# ============================================================
# STEP 8: Try Another Update
# ============================================================
print_header "Step 8: Try Another Update"

print_step "Let's update the Remote Work policy..."
echo ""

docker compose exec -T postgres psql -U demo -d demo -c \
    "UPDATE documents SET content = 'Employees may work remotely up to 4 days per week with manager approval. Remote work is encouraged for better work-life balance.' WHERE id = 2;"

print_step "Waiting for Expanso to process..."
sleep 2

print_step "Check LMCache stats again:"
curl -s http://localhost:9000/stats | python3 -m json.tool 2>/dev/null || \
    curl -s http://localhost:9000/stats

echo ""
print_success "Another automatic invalidation!"

pause

# ============================================================
# STEP 9: Insert New Document
# ============================================================
print_header "Step 9: Insert a New Document"

print_step "Adding a new document..."
echo ""

docker compose exec -T postgres psql -U demo -d demo -c \
    "INSERT INTO documents (title, content, category) VALUES ('Security Policy', 'All employees must use two-factor authentication. Passwords must be changed every 90 days.', 'policy');"

print_step "Waiting for Expanso to process..."
sleep 2

print_step "Expanso caught the INSERT too:"
docker compose logs --tail=5 expanso 2>&1 | grep -E "(Document changed|INSERT)" || \
    docker compose logs --tail=5 expanso

pause

# ============================================================
# SUMMARY
# ============================================================
print_header "Summary: What Just Happened"

echo -e "${BOLD}Without Expanso:${NC}"
print_info "• Write PostgreSQL triggers or polling service"
print_info "• Build connection management & retry logic"
print_info "• Implement error handling & logging"
print_info "• Deploy & maintain custom service"
print_info "• ${RED}500+ lines of code, 3-5 days of work${NC}"
echo ""

echo -e "${BOLD}With Expanso:${NC}"
print_info "• Write a YAML config file"
print_info "• docker compose up"
print_info "• ${GREEN}~25 lines of YAML, 10 minutes${NC}"
echo ""

echo -e "${BOLD}Files in this demo:${NC}"
echo "  docker-compose.yaml    - Service orchestration"
echo "  init.sql               - Database setup"
echo "  expanso-pipeline.yaml  - THE MAGIC (20 lines)"
echo "  lmcache_mock_api.py    - Mock API for demo"
echo ""

print_success "Demo complete!"
echo ""

# ============================================================
# CLEANUP OPTION
# ============================================================
echo -e "${YELLOW}Would you like to clean up? (y/n)${NC}"
read -r cleanup

if [[ "$cleanup" == "y" || "$cleanup" == "Y" ]]; then
    print_step "Stopping services..."
    docker compose down -v
    print_success "Cleanup complete!"
else
    print_info "Services still running. Stop with: docker compose down -v"
fi

echo ""
print_info "Learn more: https://expanso.io"
echo ""
