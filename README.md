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
terraform/                 infraestrutura AWS, modularizada
.github/workflows/         pipelines de CI/CD por serviço
scripts/                   utilitários (aplicar schema no RDS, seed de dados, etc)
docs/                       anotações sobre decisões e ajustes no código original
```