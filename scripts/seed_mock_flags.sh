#!/usr/bin/env bash
set -euo pipefail

: "${LB_URL:?defina LB_URL}"
: "${SERVICE_API_KEY:?defina SERVICE_API_KEY}"

create_flag() {
  local name="$1" description="$2" enabled="$3"
  echo "== Criando flag: $name (enabled=$enabled) =="
  curl -sf -X POST "http://${LB_URL}/flags" \
    -H "Authorization: Bearer ${SERVICE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${name}\", \"description\": \"${description}\", \"is_enabled\": ${enabled}}" \
    | python3 -m json.tool
}

create_rule() {
  local flag_name="$1" percentage="$2"
  echo "== Criando regra: $flag_name -> ${percentage}% =="
  curl -sf -X POST "http://${LB_URL}/targeting/rules" \
    -H "Authorization: Bearer ${SERVICE_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"flag_name\": \"${flag_name}\", \"rules\": {\"type\": \"PERCENTAGE\", \"value\": ${percentage}}}" \
    | python3 -m json.tool
}

create_flag "dark-mode-v2" "Nova versao do tema escuro com paleta revisada" true
create_flag "fraud-detection-realtime" "Motor de deteccao de fraude em tempo real no fluxo de pagamento" true

create_flag "pix-instant-refund" "Reembolso instantaneo via Pix para estornos de transacao" true
create_rule "pix-instant-refund" 25

create_flag "biometric-login" "Login por biometria facial no app mobile" true
create_rule "biometric-login" 60

create_flag "checkout-one-click" "Checkout em uma unica etapa, sem tela de confirmacao adicional" true
create_rule "checkout-one-click" 40

create_flag "ai-recommendation-engine" "Motor de recomendacao de produtos baseado em machine learning" true
create_rule "ai-recommendation-engine" 15

create_flag "cashback-program-v3" "Terceira versao do programa de cashback, com tiers de fidelidade" true
create_rule "cashback-program-v3" 50

create_flag "premium-support-chat" "Chat de suporte prioritario para clientes premium" false
create_rule "premium-support-chat" 80

echo
echo "Seed concluido: 8 flags criadas."
