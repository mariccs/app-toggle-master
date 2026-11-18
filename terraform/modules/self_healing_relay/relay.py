"""
Relay de self-healing (Fase 4).

Recebe o webhook do Alertmanager (quando o alerta "AuthServiceHigh5xxRate"
dispara) via uma Lambda Function URL, e chama a API repository_dispatch do
GitHub para acionar o workflow .github/workflows/self-heal.yml, que roda o
"kubectl rollout restart" de verdade dentro do cluster EKS.

Por que um relay e não o Alertmanager chamando o GitHub direto? O
Alertmanager (webhook_configs) só sabe mandar o payload fixo dele; a API
repository_dispatch do GitHub exige um corpo e um header Authorization
(Bearer <token>) específicos, que o Alertmanager não monta. Este Lambda é
a ponte entre os dois.

Só usa biblioteca padrão do Python (urllib), para não depender de nenhuma
Lambda Layer.
"""
import json
import os
import urllib.request
import urllib.error

GITHUB_API_URL = "https://api.github.com/repos/{repo}/dispatches"
EVENT_TYPE = "self-heal"

# Mapa simples: nome do label "service_name" do alerta -> nome do
# Deployment no Kubernetes. Hoje só o auth-service está mapeado para um
# alerta real (AuthServiceHigh5xxRate), mas o relay já sai pronto para
# outros serviços, caso novos alertas sejam adicionados depois.
KNOWN_SERVICES = {
    "auth-service",
    "flag-service",
    "targeting-service",
    "evaluation-service",
    "analytics-service",
}


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _extract_service_name(alertmanager_payload):
    """Lê o label service_name do primeiro alerta do payload do Alertmanager."""
    alerts = alertmanager_payload.get("alerts", [])
    if not alerts:
        return None
    service_name = alerts[0].get("labels", {}).get("service_name")
    if service_name in KNOWN_SERVICES:
        return service_name
    return None


def handler(event, context):
    # --- 1. Segredo compartilhado (header Authorization: Bearer <secret>) ---
    expected_secret = os.environ["RELAY_SHARED_SECRET"]
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    auth_header = headers.get("authorization", "")
    if auth_header != f"Bearer {expected_secret}":
        return _response(401, {"error": "não autorizado"})

    # --- 2. Lê o payload do Alertmanager e decide o serviço alvo ---
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "corpo da requisição não é JSON válido"})

    alertname = None
    if payload.get("alerts"):
        alertname = payload["alerts"][0].get("labels", {}).get("alertname")

    service_name = _extract_service_name(payload) or "auth-service"

    # --- 3. Chama a API repository_dispatch do GitHub ---
    github_token = os.environ["GITHUB_TOKEN"]
    github_repo = os.environ["GITHUB_REPO"]  # formato: "usuario/repositorio"

    dispatch_body = json.dumps({
        "event_type": EVENT_TYPE,
        "client_payload": {
            "service": service_name,
            "alert": alertname or "manual-trigger",
        },
    }).encode("utf-8")

    req = urllib.request.Request(
        GITHUB_API_URL.format(repo=github_repo),
        data=dispatch_body,
        method="POST",
        headers={
            "Authorization": f"Bearer {github_token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "togglemaster-self-healing-relay",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            status = resp.status
    except urllib.error.HTTPError as exc:
        print(f"Erro ao chamar a API do GitHub: {exc.code} {exc.read()}")
        return _response(502, {"error": "falha ao chamar a API do GitHub"})
    except urllib.error.URLError as exc:
        print(f"Erro de rede ao chamar a API do GitHub: {exc}")
        return _response(502, {"error": "falha de rede ao chamar a API do GitHub"})

    print(f"repository_dispatch disparado para {github_repo} "
          f"(service={service_name}, alert={alertname}, status={status})")
    return _response(202, {"triggered_service": service_name, "github_status": status})
