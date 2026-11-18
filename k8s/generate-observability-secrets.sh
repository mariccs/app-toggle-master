#!/usr/bin/env bash
set -euo pipefail

# Equivalente ao generate-secrets.sh, mas para os segredos da stack de
# observabilidade (Fase 4): Alertmanager (Discord, Jira Service Management, relay do
# self-healing) e a senha de admin do Grafana. Nenhum destes valores vai
# para o repositório de GitOps — só o caminho dos arquivos montados.

NAMESPACE="observability"

: "${DISCORD_WEBHOOK_URL:?defina DISCORD_WEBHOOK_URL}"
: "${JSM_API_KEY:?defina JSM_API_KEY}"
: "${SELF_HEAL_RELAY_URL:?defina SELF_HEAL_RELAY_URL}"          # output "self_healing_relay_url" do terraform
: "${SELF_HEAL_RELAY_SECRET:?defina SELF_HEAL_RELAY_SECRET}"    # mesmo valor de relay_shared_secret no terraform.tfvars
: "${GRAFANA_ADMIN_PASSWORD:?defina GRAFANA_ADMIN_PASSWORD}"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic alertmanager-chatops-secrets -n "$NAMESPACE" \
  --from-literal=DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK_URL" \
  --from-literal=JSM_API_KEY="$JSM_API_KEY" \
  --from-literal=SELF_HEAL_RELAY_URL="$SELF_HEAL_RELAY_URL" \
  --from-literal=SELF_HEAL_RELAY_SECRET="$SELF_HEAL_RELAY_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic grafana-admin-secret -n "$NAMESPACE" \
  --from-literal=admin-user="admin" \
  --from-literal=admin-password="$GRAFANA_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic otel-collector-secrets -n "$NAMESPACE" \
  --from-literal=NEW_RELIC_LICENSE_KEY="${NEW_RELIC_LICENSE_KEY:?defina NEW_RELIC_LICENSE_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets de observabilidade aplicados no namespace '$NAMESPACE'."
echo "Lembrete: a Alertmanager/Grafana/Collector (kube-prometheus-stack, loki, otel-collector)"
echo "só leem estas Secrets quando o pod sobe DEPOIS delas existirem — se o Argo CD já"
echo "sincronizou antes, reinicie os pods: kubectl rollout restart deployment -n observability --all"
