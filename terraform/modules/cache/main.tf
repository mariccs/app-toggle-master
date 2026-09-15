resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Permite acesso Redis a partir dos nos do EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis a partir dos nos do EKS"
    from_port       = 6379
    to_port         = 6379
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

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id      = "${var.project_name}-redis"
  engine          = "redis"
  engine_version  = var.redis_engine_version
  node_type       = var.redis_node_type
  num_cache_nodes = 1
  port            = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  apply_immediately = true
}
