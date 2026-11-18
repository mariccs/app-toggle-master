# ToggleMaster

Plataforma de feature flags feita de cinco microsserviços, rodando em EKS na AWS com infraestrutura toda em código, pipeline de CI/CD com verificação de segurança, e deploy via GitOps.

## Como o sistema funciona

Tem cinco peças:

- **auth-service** (Go) cuida das chaves de API — quem pode chamar o quê.
- **flag-service** (Python) guarda as definições das flags: nome, se está ligada ou desligada.
- **targeting-service** (Python) guarda as regras de segmentação, tipo "50% dos usuários".
- **evaluation-service** (Go) é o serviço que o cliente final chama de verdade: recebe um usuário e uma flag, e devolve true ou false. Usa Redis como cache pra não bater toda hora no flag-service/targeting-service.
- **analytics-service** (Python) fica ouvindo uma fila SQS e grava cada avaliação feita no DynamoDB, sem atrapalhar a resposta do evaluation-service.

RDS guarda os dados relacionais (flags e regras), ElastiCache é o cache do evaluation-service, e DynamoDB guarda o histórico de avaliações.

## Rodando localmente

```
docker compose up --build
```

Sobe os cinco serviços mais os bancos que eles precisam: dois Postgres (um pro auth-service, outro compartilhado entre flag-service e targeting-service), Redis, e um DynamoDB Local pra não precisar de conta AWS só pra testar.

Fluxo básico pra testar:

```
curl -X POST http://localhost:8001/admin/keys \
  -H "Authorization: Bearer admin-secreto-123" \
  -H "Content-Type: application/json" \
  -d '{"name": "teste"}'
```

Isso cria uma API key. Com ela dá pra criar flags no flag-service, regras no targeting-service, e chamar o /evaluate do evaluation-service.

## Infraestrutura (Terraform)

Tudo criado via Terraform modularizado — VPC própria, EKS, IAM/IRSA, os três RDS, Redis, DynamoDB, SQS, ECR, o provedor OIDC do GitHub Actions, e o ArgoCD instalado no cluster. State remoto em S3. Detalhes e passo a passo em `terraform/README.md`.

## CI/CD

Cada um dos cinco serviços tem seu próprio workflow em `.github/workflows/`, disparado por push/PR na pasta correspondente. O pipeline builda, roda lint, faz SAST (gosec/bandit) e SCA (Trivy) bloqueando em vulnerabilidade crítica, builda a imagem Docker, escaneia a imagem, publica no ECR com a tag do commit, e atualiza a tag no repositório de GitOps.

## Deploy (GitOps)

O deploy não é mais `kubectl apply` manual. Os manifestos Kubernetes vivem num repositório separado (`toggle-master-gitops`), e o ArgoCD, rodando no cluster, sincroniza automaticamente qualquer mudança lá. O pipeline de CI é quem atualiza a tag da imagem nesse repositório ao final de cada build — o ArgoCD detecta e faz o rollout sozinho.

Secrets continuam fora do Git nos dois casos — aplicados direto no cluster via `k8s/generate-secrets.sh`, usando os outputs do Terraform.

## Observabilidade, APM e self-healing (Fase 4)

Os 5 microsserviços exportam traces (e, no caso do analytics-service, os
spans das chamadas ao SQS/DynamoDB) via OTLP para um OTel Collector que
roda no próprio cluster (repositório de GitOps, `observability/`). O
Collector é o roteador central de telemetria: deriva métricas RED
automaticamente dos traces (connector `spanmetrics`, sem precisar
instrumentar manualmente um contador por serviço) e distribui para:

- **Prometheus + Grafana** (`kube-prometheus-stack`) — métricas e o
  dashboard `ToggleMaster - Visão Geral`;
- **Loki** — logs, via o endpoint OTLP nativo do próprio Loki;
- **New Relic** — APM comercial desta fase (traces, métricas e logs).

Um alerta no Prometheus (`AuthServiceHigh5xxRate`, taxa de 5xx do
auth-service acima de 5% por 2 minutos) dispara, via Alertmanager, três
coisas em paralelo: abre um incidente na **Jira Service Management**, manda uma
notificação no **Discord** (ChatOps), e aciona o **self-healing** — um
pequeno relay em AWS Lambda (`terraform/modules/self_healing_relay/`)
chama a API `repository_dispatch` do GitHub, que dispara o workflow
`.github/workflows/self-heal.yml` e executa
`kubectl rollout restart deployment/auth-service` de verdade no cluster.

Para provocar a falha de propósito (demonstração), o auth-service expõe
`GET /auth/chaos/5xx` (via ingress) quando sobe com `CHAOS_ENDPOINT_ENABLED=true` — endpoint
que só serve pra isso, desligado por padrão.

Detalhes de arquitetura, a justificativa das escolhas (New Relic vs
Datadog, Jira Service Management) e o passo a passo de configuração dos
segredos estão em `docs/CHANGES.md` e no relatório de entrega da Fase 4.
Os arquivos do Helm/ArgoCD da stack de observabilidade ficam no
repositório `toggle-master-gitops`, pasta `observability/`.

## Estrutura do repositório

```
auth-service/            código do serviço + Dockerfile
flag-service/
targeting-service/
evaluation-service/
analytics-service/
compose/init/             scripts de inicialização dos bancos locais
docker-compose.yml
k8s/                       geração de secrets (não manifestos de app - esses foram pro repo de GitOps)
terraform/                 infraestrutura AWS, modularizada (inclui o relay de self-healing da Fase 4)
.github/workflows/         pipelines de CI/CD por serviço + self-heal.yml (Fase 4)
scripts/                   utilitários (aplicar schema no RDS, seed de dados, etc)
docs/                       anotações sobre decisões e ajustes no código original
```

A stack de observabilidade (Prometheus, Loki, Grafana, OTel Collector) é
GitOps puro e não vive aqui — está em `observability/` no repositório
`toggle-master-gitops`.
