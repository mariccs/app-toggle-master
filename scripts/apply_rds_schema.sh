#!/usr/bin/env bash
set -euo pipefail

: "${DB_USERNAME:?defina DB_USERNAME}"
: "${DB_PASSWORD:?defina DB_PASSWORD}"
: "${AUTH_DB_HOST:?defina AUTH_DB_HOST}"
: "${FLAG_DB_HOST:?defina FLAG_DB_HOST}"
: "${TARGETING_DB_HOST:?defina TARGETING_DB_HOST}"

NAMESPACE="togglemaster"

apply_schema() {
  local label="$1" host="$2" dbname="$3" sqlfile="$4"

  echo "== Aplicando schema em ${label} (${host}/${dbname}) =="
  cat "$sqlfile" | kubectl run "psql-migrate-${label}" \
    --namespace "$NAMESPACE" \
    --rm -i --restart=Never \
    --image=postgres:15-alpine \
    --env="PGPASSWORD=${DB_PASSWORD}" \
    -- psql "postgresql://${DB_USERNAME}@${host}:5432/${dbname}?sslmode=require" -f -
}

apply_schema "auth" "$AUTH_DB_HOST" "auth_db" "auth-service/db/init.sql"
apply_schema "flag" "$FLAG_DB_HOST" "flags_db" "flag-service/db/init.sql"
apply_schema "targeting" "$TARGETING_DB_HOST" "targeting_db" "targeting-service/db/init.sql"

echo "Schema aplicado nas 3 instâncias RDS."
