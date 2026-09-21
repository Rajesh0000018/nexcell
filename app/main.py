import os

import psycopg
import redis.asyncio as redis
from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(title="NexCell assessment API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}


@app.get("/ready")
async def ready():
    failed = []
    redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
    redis_client = redis.from_url(redis_url, socket_connect_timeout=3, socket_timeout=3)
    try:
        await redis_client.ping()
    except Exception:
        failed.append("redis")
    finally:
        await redis_client.aclose()

    try:
        async with await psycopg.AsyncConnection.connect(
            os.environ["DATABASE_URL"], connect_timeout=3
        ) as connection:
            await connection.execute("SELECT 1")
    except Exception:
        failed.append("postgres")

    if failed:
        return JSONResponse({"status": "not ready", "failed": failed}, status_code=503)
    return {"status": "ready", "redis": "connected", "postgres": "connected"}
