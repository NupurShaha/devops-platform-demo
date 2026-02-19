"""
DevOps Platform Worker — processes messages from RabbitMQ.
"""
import os, json, asyncio, signal
import asyncpg, aio_pika

RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://devops:devops-rabbit-pass@rabbitmq:5672/devops_demo")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://devops:devops-demo-pass@postgresql:5432/devops_demo")
VERSION = os.getenv("APP_VERSION", "1.0.0")
running = True

def handle_signal(signum, frame):
    global running
    running = False

signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)

async def process_message(message, db_pool):
    async with message.process():
        body = json.loads(message.body.decode())
        print(f"[worker] Processing: {body}")
        try:
            async with db_pool.acquire() as conn:
                await conn.execute(
                    "INSERT INTO events (event_type, source, message, severity) VALUES ($1, $2, $3, $4)",
                    body.get("type","unknown"), body.get("source","worker"),
                    body.get("message",""), body.get("severity","info"))
            print(f"[worker] Saved event")
        except Exception as e:
            print(f"[worker] DB error: {e}")

async def main():
    global running
    print(f"[worker] Starting v{VERSION}")
    db_pool = None
    for attempt in range(30):
        try:
            db_pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=3)
            print("[worker] Connected to PostgreSQL")
            break
        except Exception:
            print(f"[worker] Waiting for PostgreSQL... ({attempt+1}/30)")
            await asyncio.sleep(2)
    if not db_pool:
        print("[worker] FATAL: Could not connect to PostgreSQL")
        return

    connection = None
    for attempt in range(30):
        try:
            connection = await aio_pika.connect_robust(RABBITMQ_URL)
            print("[worker] Connected to RabbitMQ")
            break
        except Exception:
            print(f"[worker] Waiting for RabbitMQ... ({attempt+1}/30)")
            await asyncio.sleep(2)
    if not connection:
        print("[worker] FATAL: Could not connect to RabbitMQ")
        return

    channel = await connection.channel()
    await channel.set_qos(prefetch_count=10)
    queue = await channel.declare_queue("events", durable=True)
    print("[worker] Listening for messages on 'events' queue...")

    while running:
        try:
            message = await asyncio.wait_for(queue.get(timeout=5), timeout=10)
            if message:
                await process_message(message, db_pool)
        except asyncio.TimeoutError:
            continue
        except aio_pika.exceptions.QueueEmpty:
            await asyncio.sleep(1)
        except Exception as e:
            print(f"[worker] Error: {e}")
            await asyncio.sleep(2)

    await connection.close()
    await db_pool.close()
    print("[worker] Shutdown complete")

if __name__ == "__main__":
    asyncio.run(main())
