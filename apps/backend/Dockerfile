FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
RUN addgroup --system --gid 1000 app && \
    adduser --system --uid 1000 --ingroup app app
COPY --from=builder /deps /deps
COPY src/ ./src/
ENV PYTHONPATH=/deps
USER app
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
