resource "aws_security_group" "rds_postgres" {
  name        = "${var.project_name}-rds-postgres-sg"
  description = "Permite acesso PostgreSQL a partir dos nos do EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL a partir dos nos do EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

locals {
  rds_databases = {
    auth      = { db_name = "auth_db" }
    flag      = { db_name = "flags_db" }
    targeting = { db_name = "targeting_db" }
  }
}

resource "aws_db_instance" "this" {
  for_each = local.rds_databases

  identifier     = "${var.project_name}-${each.key}"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type       = "gp3"
  storage_encrypted  = true

  db_name  = each.value.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds_postgres.id]
  publicly_accessible    = false
  multi_az                = var.db_multi_az

  backup_retention_period = var.db_backup_retention_period
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name    = "${var.project_name}-${each.key}"
    Service = "${each.key}-service"
  }
}
