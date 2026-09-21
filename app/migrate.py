import os

import psycopg

SCHEMA = """
CREATE TABLE IF NOT EXISTS processed_jobs (
    job_id TEXT PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
)
"""


def main() -> None:
    with psycopg.connect(os.environ["DATABASE_URL"], connect_timeout=5) as connection:
        connection.execute(SCHEMA)
    print("Migration completed", flush=True)


if __name__ == "__main__":
    main()
