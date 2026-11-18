#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?defina AWS_REGION}"
: "${AWS_ACCOUNT_ID:?defina AWS_ACCOUNT_ID}"

REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
SERVICES=(auth-service flag-service targeting-service evaluation-service analytics-service)

echo "Autenticando no ECR ($REGISTRY)..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"

for svc in "${SERVICES[@]}"; do
  echo "== Build: $svc (linux/amd64) =="
  docker build --platform linux/amd64 -t "${svc}:latest" "./${svc}"
  docker tag "${svc}:latest" "${REGISTRY}/${svc}:latest"

  echo "== Push: $svc =="
  docker push "${REGISTRY}/${svc}:latest"
done

echo "Todas as imagens publicadas em ${REGISTRY}"
