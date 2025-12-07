from fastapi import FastAPI
import time, random
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()
Instrumentator().instrument(app).expose(app)

@app.get("/")
async def root():
    return {"message": "Hello from KEDA demo"}

@app.get("/work")
async def work():
    delay = random.uniform(0.05, 0.2)
    end = time.time() + delay
    while time.time() < end:
        pass  # Busy‑loop
    return {"work_duration_s": round(delay, 3)}
