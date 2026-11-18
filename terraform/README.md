# Infraestrutura AWS

Projeto modularizado. Cada módulo em `modules/` cuida de uma parte; `environments/sandbox/` amarra tudo. `bootstrap/` cria o bucket S3 do backend remoto — só precisa rodar uma vez.

```
modules/
  networking/       VPC, subnets públicas/privadas, IGW, NAT, route tables
  iam/               role do cluster e dos nós
  eks/               cluster EKS, node group, addons, provedor OIDC
  irsa/              roles de IAM por pod (evaluation-service, analytics-service)
  database/          3 instâncias RDS Postgres
  cache/             ElastiCache Redis
  dynamodb/
  messaging/         fila SQS + DLQ
  ecr/               5 repositórios
  github_oidc/       provedor OIDC do GitHub Actions + role de CI
  argocd/             instala o ArgoCD via Helm
environments/
  sandbox/            ambiente principal
bootstrap/            bucket S3 do state remoto
```

## 1. Backend remoto (uma vez só)

```bash
cd bootstrap
terraform init
terraform apply
terraform output bucket_name
```

## 2. Ambiente principal

```bash
cd ../environments/sandbox
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
```

Cola o nome do bucket (do passo anterior) em `backend.hcl`. Preenche `github_org_repo` no `terraform.tfvars` com `seu-usuario/toggle-master` (é usado pra restringir quem consegue assumir a role de CI via OIDC).

```bash
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Isso cria: VPC com subnets públicas e privadas, cluster EKS + node group, IAM dedicado + IRSA, 3 RDS, Redis, DynamoDB, SQS, 5 repositórios ECR, o provedor OIDC do GitHub Actions com a role de CI, e o ArgoCD instalado no cluster.

## Depois do apply

```bash
$(terraform output -raw eks_update_kubeconfig_command)
```

Outputs relevantes pra configurar o resto (secrets do k8s, repositório de GitOps, CI):

```bash
terraform output
terraform output -raw db_password
terraform output github_actions_role_arn
terraform output irsa_evaluation_service_role_arn
terraform output irsa_analytics_service_role_arn
```

O `github_actions_role_arn` vai como secret `AWS_GITHUB_ACTIONS_ROLE_ARN` no repositório principal do GitHub, pra pipeline autenticar na AWS sem chave fixa.

## Desligando tudo

```bash
helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null
terraform destroy
```

O bucket do backend (`bootstrap/`) não é destruído automaticamente de propósito (`prevent_destroy`) — se quiser apagar mesmo assim, remova o lifecycle e rode `terraform destroy` dentro de `bootstrap/`.
