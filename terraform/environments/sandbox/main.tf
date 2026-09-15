resource "random_password" "db_master" {
  count   = var.db_password == null ? 1 : 0
  length  = 24
  special = false
}

locals {
  db_password = var.db_password != null ? var.db_password : random_password.db_master[0].result
}

module "networking" {
  source = "../../modules/networking"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  azs                   = var.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  single_nat_gateway    = var.single_nat_gateway
  cluster_name          = "${var.project_name}-${var.environment}"
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
}

module "eks" {
  source = "../../modules/eks"

  project_name         = var.project_name
  environment          = var.environment
  cluster_role_arn     = module.iam.cluster_role_arn
  node_role_arn        = module.iam.node_role_arn
  private_subnet_ids   = module.networking.private_subnet_ids
  public_subnet_ids    = module.networking.public_subnet_ids
  kubernetes_version   = var.kubernetes_version
  node_instance_types  = var.node_instance_types
  node_min_size        = var.node_min_size
  node_desired_size    = var.node_desired_size
  node_max_size        = var.node_max_size
}

module "database" {
  source = "../../modules/database"

  project_name               = var.project_name
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  cluster_security_group_id   = module.eks.cluster_security_group_id
  db_instance_class           = var.db_instance_class
  db_engine_version           = var.db_engine_version
  db_allocated_storage        = var.db_allocated_storage
  db_username                 = var.db_username
  db_password                 = local.db_password
  db_multi_az                 = var.db_multi_az
  db_backup_retention_period  = var.db_backup_retention_period
}

module "cache" {
  source = "../../modules/cache"

  project_name               = var.project_name
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  cluster_security_group_id   = module.eks.cluster_security_group_id
  redis_node_type              = var.redis_node_type
  redis_engine_version         = var.redis_engine_version
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name = var.dynamodb_table_name
}

module "messaging" {
  source = "../../modules/messaging"

  queue_name = var.sqs_queue_name
}

module "ecr" {
  source = "../../modules/ecr"

  repository_names = var.ecr_repository_names
}

module "irsa" {
  source = "../../modules/irsa"

  project_name        = var.project_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  sqs_queue_arn       = module.messaging.queue_arn
  dynamodb_table_arn  = module.dynamodb.table_arn
}

module "argocd" {
  source = "../../modules/argocd"
  count  = var.install_argocd ? 1 : 0
}

module "github_oidc" {
  source = "../../modules/github_oidc"

  project_name         = var.project_name
  github_org_repo      = var.github_org_repo
  ecr_repository_arns  = values(module.ecr.repository_arns)
}
