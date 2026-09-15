#!/usr/bin/env bash
set -euo pipefail

: "${DB_USERNAME:?defina DB_USERNAME}"
: "${DB_PASSWORD:?defina DB_PASSWORD}"
: "${FLAG_DB_HOST:?defina FLAG_DB_HOST}"
: "${TARGETING_DB_HOST:?defina TARGETING_DB_HOST}"
: "${SQS_URL:?defina SQS_URL}"
: "${DYNAMODB_TABLE:?defina DYNAMODB_TABLE}"

NAMESPACE="togglemaster"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "== Limpando tabela flags (flags_db) =="
kubectl run psql-reset-flags \
  --namespace "$NAMESPACE" \
  --rm -i --restart=Never \
  --image=postgres:15-alpine \
  --env="PGPASSWORD=${DB_PASSWORD}" \
  -- psql "postgresql://${DB_USERNAME}@${FLAG_DB_HOST}:5432/flags_db?sslmode=require" \
  -c "TRUNCATE TABLE flags RESTART IDENTITY CASCADE;"

echo "== Limpando tabela targeting_rules (targeting_db) =="
kubectl run psql-reset-targeting \
  --namespace "$NAMESPACE" \
  --rm -i --restart=Never \
  --image=postgres:15-alpine \
  --env="PGPASSWORD=${DB_PASSWORD}" \
  -- psql "postgresql://${DB_USERNAME}@${TARGETING_DB_HOST}:5432/targeting_db?sslmode=require" \
  -c "TRUNCATE TABLE targeting_rules RESTART IDENTITY CASCADE;"

echo "== Purgando fila SQS (mensagens de teste acumuladas) =="
aws sqs purge-queue --queue-url "$SQS_URL" --region "$AWS_REGION" || \
  echo "  (purge-queue só pode ser chamado 1x a cada 60s por fila; se falhou por isso, ignore)"

echo "== Apagando itens de teste do DynamoDB =="
EVENT_IDS=$(aws dynamodb scan --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" \
  --query 'Items[].event_id.S' --output text)

if [ -n "$EVENT_IDS" ]; then
  TOTAL=$(echo "$EVENT_IDS" | wc -w | tr -d ' ')
  echo "  ${TOTAL} itens encontrados. Apagando em lotes de 25 (batch-write-item)..."

  echo "$EVENT_IDS" | tr ' ' '\n' | xargs -n 25 | while read -r batch; do
    REQUESTS=$(python3 -c "
import json, sys
ids = sys.argv[1:]
reqs = [{'DeleteRequest': {'Key': {'event_id': {'S': i}}}} for i in ids]
print(json.dumps(reqs))
" $batch)
    aws dynamodb batch-write-item --region "$AWS_REGION" \
      --request-items "{\"${DYNAMODB_TABLE}\": ${REQUESTS}}" > /dev/null
    echo -n "."
  done
  echo
  echo "  ${TOTAL} itens removidos."
else
  echo "  Nenhum item encontrado."
fi

echo "Reset concluído. api_keys NÃO foi tocado (sua SERVICE_API_KEY continua válida)."
