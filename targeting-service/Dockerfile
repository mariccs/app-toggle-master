FROM python:3.11-slim AS builder

WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim

RUN groupadd -r app && useradd -r -g app app \
    && apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app
COPY . .

USER app
EXPOSE 8003

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fs http://127.0.0.1:8003/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8003", "--workers", "2", "--threads", "4", "app:app"]
