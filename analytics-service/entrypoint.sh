#!/bin/sh
set -e

if [ -n "$AWS_DYNAMODB_ENDPOINT_URL" ]; then
    echo "[entrypoint] AWS_DYNAMODB_ENDPOINT_URL definido - garantindo tabela no DynamoDB Local..."
    python create_table_if_local.py || true
fi

exec "$@"
