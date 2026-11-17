# Billing owns its PostgreSQL instance: no other service has network rules,
# credentials or schema knowledge of it. One database per environment
# (billing_prod / billing_homolog), created by `db:prepare` in the migrate job.
resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.service}-db"
  subnet_ids = local.private_subnet_ids
}

resource "aws_security_group" "db" {
  name        = "${var.project}-${var.service}-db"
  description = "PostgreSQL access to the Billing database from inside the VPC"
  vpc_id      = local.vpc_id

  ingress {
    description = "PostgreSQL from the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project}-${var.service}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "billing_prod"
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
