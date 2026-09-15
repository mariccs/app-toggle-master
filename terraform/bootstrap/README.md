# Bootstrap do backend remoto

Isso cria só o bucket S3 que vai guardar o `terraform.tfstate` do projeto principal. É um passo único, roda uma vez, com state local mesmo (é o único lugar do projeto onde isso é aceitável, já que não tem outro backend disponível ainda pra guardar o state de si mesmo).

```bash
cd terraform/bootstrap
terraform init
terraform apply
terraform output bucket_name
```

Copia o valor de `bucket_name` e cola em `terraform/environments/sandbox/backend.hcl` antes de inicializar o ambiente principal.
