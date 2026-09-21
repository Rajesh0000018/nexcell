import os

from redis import Redis


def main() -> None:
    redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
    client = Redis.from_url(redis_url, decode_responses=True, socket_connect_timeout=5)
    client.ping()
    while True:
        job = client.blpop("jobs", timeout=5)
        if job:
            job_id = job[1]
            result = f"processed:{job_id}"
            client.setex(f"result:{job_id}", 300, result)
            print(result, flush=True)


if __name__ == "__main__":
    main()
