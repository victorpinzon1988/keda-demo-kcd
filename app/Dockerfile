FROM python:3.12-slim AS base

RUN pip install --no-cache-dir fastapi uvicorn prometheus-fastapi-instrumentator

WORKDIR /app
COPY main.py .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]