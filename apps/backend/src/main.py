"""
DevOps Platform Backend — FastAPI
Serves the deployment dashboard API with live cluster data.
"""
import os
import time
import asyncio
from datetime import datetime
from contextlib import asynccontextmanager

import asyncpg
import redis.asyncio as aioredis
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# ── Config ─────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://devops:devops-demo-pass@postgresql:5432/devops_demo")
REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "production")
VERSION = os.getenv("APP_VERSION", "1.0.0")

# ── Global connections ─────────────────────────────────────
db_pool = None
redis_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global db_pool, redis_client
    # Startup
    try:
        db_pool = await asyncpg.create_pool(DATABASE_URL, min_size=2, max_size=5)
    except Exception as e:
        print(f"[WARN] PostgreSQL not available: {e}")
    try:
        redis_client = aioredis.from_url(REDIS_URL, decode_responses=True)
        await redis_client.ping()
    except Exception as e:
        print(f"[WARN] Redis not available: {e}")
        redis_client = None
    yield
    # Shutdown
    if db_pool:
        await db_pool.close()
    if redis_client:
        await redis_client.close()

app = FastAPI(
    title="DevOps Platform API",
    version=VERSION,
    docs_url="/api/docs",
    openapi_url="/api/openapi.json",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)

START_TIME = time.time()


# ── Health & Info ──────────────────────────────────────────
@app.get("/api/health")
async def health():
    checks = {"api": "healthy"}

    # Check PostgreSQL
    try:
        if db_pool:
            async with db_pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            checks["postgresql"] = "healthy"
        else:
            checks["postgresql"] = "unavailable"
    except Exception:
        checks["postgresql"] = "unhealthy"

    # Check Redis
    try:
        if redis_client:
            await redis_client.ping()
            checks["redis"] = "healthy"
        else:
            checks["redis"] = "unavailable"
    except Exception:
        checks["redis"] = "unhealthy"

    overall = "healthy" if all(v == "healthy" for v in checks.values()) else "degraded"
    return {"status": overall, "checks": checks, "version": VERSION}


@app.get("/api/info")
async def info():
    uptime = int(time.time() - START_TIME)
    return {
        "service": "devops-platform-backend",
        "version": VERSION,
        "environment": ENVIRONMENT,
        "uptime_seconds": uptime,
        "uptime_human": f"{uptime // 3600}h {(uptime % 3600) // 60}m {uptime % 60}s",
    }


# ── Deployments ────────────────────────────────────────────
@app.get("/api/deployments")
async def get_deployments():
    if not db_pool:
        raise HTTPException(503, "Database not available")
    async with db_pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM deployments ORDER BY deployed_at DESC LIMIT 50"
        )
    return [dict(r) for r in rows]


@app.get("/api/deployments/latest")
async def get_latest_deployments():
    """Latest deployment per service — used by dashboard status grid."""
    if not db_pool:
        raise HTTPException(503, "Database not available")
    async with db_pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT DISTINCT ON (service_name)
                service_name, version, status, deployed_at, commit_sha, duration_seconds
            FROM deployments
            ORDER BY service_name, deployed_at DESC
        """)
    return [dict(r) for r in rows]


# ── Events ─────────────────────────────────────────────────
@app.get("/api/events")
async def get_events():
    if not db_pool:
        raise HTTPException(503, "Database not available")
    async with db_pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM events ORDER BY created_at DESC LIMIT 100"
        )
    return [dict(r) for r in rows]


# ── Platform Stats (cached in Redis) ──────────────────────
@app.get("/api/stats")
async def get_stats():
    """Aggregate platform statistics — cached 30s in Redis."""
    cache_key = "platform:stats"

    # Try cache first
    if redis_client:
        try:
            cached = await redis_client.get(cache_key)
            if cached:
                import json
                return json.loads(cached)
        except Exception:
            pass

    stats = {
        "total_deployments": 0,
        "successful_deployments": 0,
        "services_count": 0,
        "avg_deploy_duration_seconds": 0,
        "uptime_seconds": int(time.time() - START_TIME),
    }

    if db_pool:
        try:
            async with db_pool.acquire() as conn:
                stats["total_deployments"] = await conn.fetchval(
                    "SELECT COUNT(*) FROM deployments"
                )
                stats["successful_deployments"] = await conn.fetchval(
                    "SELECT COUNT(*) FROM deployments WHERE status = 'success'"
                )
                stats["services_count"] = await conn.fetchval(
                    "SELECT COUNT(DISTINCT service_name) FROM deployments"
                )
                avg = await conn.fetchval(
                    "SELECT AVG(duration_seconds) FROM deployments WHERE status = 'success'"
                )
                stats["avg_deploy_duration_seconds"] = round(float(avg or 0), 1)
        except Exception:
            pass

    # Cache for 30 seconds
    if redis_client:
        try:
            import json
            await redis_client.setex(cache_key, 30, json.dumps(stats))
        except Exception:
            pass

    return stats


# ── Metrics endpoint (for Prometheus) ──────────────────────
@app.get("/api/metrics")
async def metrics():
    """Simple Prometheus-format metrics."""
    uptime = int(time.time() - START_TIME)
    lines = [
        "# HELP backend_uptime_seconds Backend uptime in seconds",
        "# TYPE backend_uptime_seconds gauge",
        f'backend_uptime_seconds{{version="{VERSION}"}} {uptime}',
        "# HELP backend_info Backend service info",
        "# TYPE backend_info gauge",
        f'backend_info{{version="{VERSION}",environment="{ENVIRONMENT}"}} 1',
    ]

    if db_pool:
        try:
            async with db_pool.acquire() as conn:
                count = await conn.fetchval("SELECT COUNT(*) FROM deployments")
                lines.append("# HELP backend_deployments_total Total deployments")
                lines.append("# TYPE backend_deployments_total counter")
                lines.append(f"backend_deployments_total {count}")
        except Exception:
            pass

    return JSONResponse(content="\n".join(lines) + "\n", media_type="text/plain")
