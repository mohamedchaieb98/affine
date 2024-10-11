resource "random_password" "rds_password" {
  length  = 16
  special = true
  override_special = "_%$#!§:@?�"
}

resource "aws_secretsmanager_secret" "rds_password_secret" {
  name = "password_affine_rds"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "rds_password_secret_version" {
  secret_id     = aws_secretsmanager_secret.rds_password_secret.id
  secret_string = random_password.rds_password.result
}

resource "aws_security_group" "rds_sg" {
  name   = "rds-sg"
  vpc_id = data.aws_vpc.vpc_affine.id
  ingress {
    self = true
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
  }  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "affine_subnet" {
  name       = "affine-subnet-group"
  subnet_ids = data.aws_subnets.private_subnets.ids

  tags = {
    Name = "affine-subnet-group"
  }
}

resource "aws_db_instance" "affine" {
  identifier             = "affinedb"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  db_name                = "affinedb"
  username               = "affine"
  password               = random_password.rds_password.result
  parameter_group_name   = "default.postgres16"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.affine_subnet.id
}
