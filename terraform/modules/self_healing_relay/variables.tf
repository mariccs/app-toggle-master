variable "project_name" {
  type = string
}

variable "github_org_repo" {
  description = "No formato usuario/repositorio, ex: mariccs/toggle-master"
  type        = string
}

variable "github_dispatch_token" {
  description = "Personal Access Token do GitHub (fine-grained, só com permissão de 'Contents: Read and write' ou 'Actions: Read and write' no repositório) usado pelo Lambda para chamar a API repository_dispatch."
  type        = string
  sensitive   = true
}

variable "relay_shared_secret" {
  description = "Segredo compartilhado que o Alertmanager envia no header Authorization (Bearer) e que o Lambda valida antes de aceitar a chamada."
  type        = string
  sensitive   = true
}
