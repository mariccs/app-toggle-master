# Secrets

Os manifestos de aplicação (Deployment, Service, Ingress, HPA) saíram daqui na Fase 3 — agora vivem no repositório separado `toggle-master-gitops`, sincronizado automaticamente pelo ArgoCD.

O que continua aqui é só o que não deveria ir por Git de jeito nenhum: os Secrets. `02-secrets.template.yaml` é referência de formato, não pra aplicar direto. Os valores reais são gerados a partir dos outputs do Terraform:

```bash
export AUTH_DB_URL="postgres://..."
export FLAG_DB_URL="postgres://..."
export TARGETING_DB_URL="postgres://..."
export MASTER_KEY="..."
export REDIS_URL="redis://..."
export SERVICE_API_KEY="..."
export SQS_URL="..."

./generate-secrets.sh
```

Isso precisa rodar uma vez, direto contra o cluster, antes do ArgoCD sincronizar as aplicações — os Deployments esperam esses Secrets já existirem no namespace `togglemaster`.
