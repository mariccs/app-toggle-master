variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_security_group_id" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_engine_version" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_multi_az" {
  type = bool
}

variable "db_backup_retention_period" {
  type = number
}
