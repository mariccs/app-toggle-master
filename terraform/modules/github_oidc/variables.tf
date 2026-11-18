variable "project_name" {
  type = string
}

variable "github_org_repo" {
  description = "No formato usuario/repositorio, ex: mariacustodio/toggle-master"
  type        = string
}

variable "ecr_repository_arns" {
  type = list(string)
}

variable "eks_cluster_name" {
  description = "Nome do cluster EKS, usado para liberar o self-healing (rollout restart) via Access Entry."
  type        = string
}
