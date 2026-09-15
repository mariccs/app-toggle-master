variable "project_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "namespace" {
  type    = string
  default = "togglemaster"
}

variable "sqs_queue_arn" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}
