# Expanso + LMCache Demo

> **When your data changes, your cache should too.**

Automatically invalidate LLM cache when your documents update. No custom code. Just ~25 lines of YAML.

## The Problem

You've built a RAG system with LMCache for fast responses. But when someone updates a document in your database, your LLM keeps serving **stale cached answers**. Users get wrong information. Chaos ensues.

## The Solution

**Expanso** watches your database and automatically tells **LMCache** to clear stale entries. Changes propagate in seconds.

```
PostgreSQL → Expanso → LMCache → Fresh Answers
```

## Quick Start

```bash
# Start everything
docker compose up -d

# Run the interactive demo
./demo.sh
```

## What's Inside

| File | Purpose |
|------|---------|
| `docker-compose.yaml` | PostgreSQL, Redis, LMCache API, Expanso |
| `expanso-pipeline.yaml` | **The magic** — ~25 lines that do everything |
| `demo.sh` | Interactive walkthrough |
| `index.html` | [Full documentation](https://expanso-io.github.io/lmcache-sync/) |

## The Pipeline (That's It. Really.)

```yaml
input:
  generate:
    interval: 2s

pipeline:
  processors:
    - sql_raw:
        driver: postgres
        dsn: "${POSTGRES_DSN}"
        query: "SELECT id, title FROM documents
                WHERE updated_at > NOW() - INTERVAL '5 seconds'"
    - mapping: |
        root.document_id = this.id
        root.reason = "Document updated: " + this.title

output:
  http_client:
    url: "${LMCACHE_API_URL}/clear"
    verb: POST
```

## Try It

```bash
# Update a document
docker compose exec postgres psql -U demo -d demo -c \
  "UPDATE documents SET content='New policy', updated_at=NOW() WHERE id=1;"

# Watch the logs
docker compose logs -f expanso

# Check invalidations
curl http://localhost:9000/stats
```

## Bonus: Token Anxiety Dashboard

"Token anxiety" is real — rate limits and costs killing your agent workflows?

```bash
# Simulate agent traffic
curl -X POST "http://localhost:9000/simulate-traffic?requests=100"

# See your savings
curl http://localhost:9000/savings | python3 -m json.tool
```

**The math**: Cache hit = $0 input tokens. At 75% hit rate, that's **$2,100/month saved** on 100k requests.

## Why Not Just...

| Alternative | Problem |
|-------------|---------|
| PostgreSQL triggers | Adds DB complexity, no retry logic, hard to monitor |
| Custom polling service | 500+ lines of code, 3-5 days to build, ongoing maintenance |
| Manual invalidation | Human error, forgotten edge cases, doesn't scale |

## Cleanup

```bash
docker compose down -v
```

## Learn More

- [Full Documentation](./index.html) — Detailed explanation with visuals
- [Expanso Docs](https://docs.expanso.io)
- [LMCache GitHub](https://github.com/LMCache/LMCache)
- [Redpanda Connect](https://docs.redpanda.com/redpanda-connect)
