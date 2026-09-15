#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="togglemaster"

: "${AUTH_DB_URL:?defina AUTH_DB_URL}"
: "${FLAG_DB_URL:?defina FLAG_DB_URL}"
: "${TARGETING_DB_URL:?defina TARGETING_DB_URL}"
: "${MASTER_KEY:?defina MASTER_KEY}"
: "${REDIS_URL:?defina REDIS_URL}"
: "${SERVICE_API_KEY:?defina SERVICE_API_KEY}"
: "${SQS_URL:?defina SQS_URL}"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic auth-service-secrets -n "$NAMESPACE" \
  --from-literal=DATABASE_URL="$AUTH_DB_URL" \
  --from-literal=MASTER_KEY="$MASTER_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic flag-service-secrets -n "$NAMESPACE" \
  --from-literal=DATABASE_URL="$FLAG_DB_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic targeting-service-secrets -n "$NAMESPACE" \
  --from-literal=DATABASE_URL="$TARGETING_DB_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic evaluation-service-secrets -n "$NAMESPACE" \
  --from-literal=REDIS_URL="$REDIS_URL" \
  --from-literal=SERVICE_API_KEY="$SERVICE_API_KEY" \
  --from-literal=AWS_SQS_URL="$SQS_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic analytics-service-secrets -n "$NAMESPACE" \
  --from-literal=AWS_SQS_URL="$SQS_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets aplicados no namespace '$NAMESPACE'."
