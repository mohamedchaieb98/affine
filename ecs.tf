resource "random_password" "affine_password" {
  length  = 16
  special = true
  override_special = "_%$#!§:@?"
}

resource "aws_secretsmanager_secret" "affine_password_secret" {
  name = "affine_admin_mdp"
}

resource "aws_secretsmanager_secret_version" "affine_password_secret_version" {
  secret_id     = aws_secretsmanager_secret.affine_password_secret.id
  secret_string = random_password.affine_password.result
}
resource "aws_ecs_cluster" "affine_cluster" {
  name = "affine-cluster"
}

resource "aws_elasticache_serverless_cache" "redis_cluster" {
  engine                   = "redis"
  name                     = "redis-cluster"
  description              = "Redis Cache Server"
  major_engine_version     = "7"
  security_group_ids       = [aws_security_group.redis_sg.id]
  subnet_ids               = [data.aws_subnets.public_subnets.ids[1],data.aws_subnets.public_subnets.ids[0]]
  tags = module.tagging.tags
}
resource "aws_ecs_task_definition" "affine_task" {
  family                   = "affine"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "AFFINE"
      image     = "ghcr.io/toeverything/affine-graphql:stable"
      memory    = 2048
      cpu       = 1024
      essential = true
      portMappings = [
        {
          containerPort = 3010
          hostPort      = 3010
        },
        {
          containerPort = 5555
          hostPort      = 5555
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.affine.name
          awslogs-region        = "eu-west-3"
          awslogs-stream-prefix = "ecs"
        }
      }
      command =["sh", "-c", "node ./scripts/self-host-predeploy && node ./dist/index.js"]
      environment = [
        {
          name = "AFFINE_SERVER_HTTPS"
          value = "false"
        },        {
          name = "AFFINE_SERVER_HOST"
          value = "affine-alb-649464953.eu-west-3.elb.amazonaws.com"
        },
        {name ="AFFINE_SERVER_PORT"
        valus = "80"},
        {
          name  = "DATABASE_URL"
          value = "postgresql://${aws_db_instance.affine.username}:${random_password.rds_password.result}@${aws_db_instance.affine.endpoint}/${aws_db_instance.affine.db_name}"
        },
        {
          name  = "AFFINE_ADMIN_EMAIL"
          value = var.AFFINE_ADMIN_EMAIL
        },
        {
          name  = "AFFINE_ADMIN_PASSWORD"
          value = random_password.affine_password.result
        },
        { name = "REDIS_SERVER_HOST"
          value = "redis-cluster-98i07s.serverless.euw3.cache.amazonaws.com"
        }
      ]
    }
  ])
}

resource "aws_security_group" "ecs_service_sg" {
  name   = "ecs-service-sg"
  vpc_id = data.aws_vpc.vpc_affine.id
  
  ingress  {
     from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "redis_sg" {
  name        = "redis-security-group"
  description = "Security group for Redis"
  vpc_id      = data.aws_vpc.vpc_affine.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "affine_service" {
  name            = "affine-service"
  cluster         = aws_ecs_cluster.affine_cluster.id
  task_definition = aws_ecs_task_definition.affine_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = data.aws_subnets.private_subnets.ids
    security_groups  = [aws_security_group.ecs_service_sg.id,aws_security_group.rds_sg.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.affine_tg.arn
    container_name   = "AFFINE"
    container_port   = 3010
  }
  # depends_on = [aws_lb_listener.n8n_listener_https]
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "affineEcsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  inline_policy {
    name = "SecretsManagerAccessPolicy"

    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
          ],
          Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:affine_admin_password"
        }
      ]
    })
  }
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
resource "aws_iam_policy_attachment" "ecs_task_execution_policy" {
  name       = "affineEcsTaskExecutionPolicyAttachment"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_policy" {
  name = "affineEcsTaskExecutionPolicyAttachmentForCW"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}


resource "aws_lb" "affine_alb" {
  name               = "affine-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.affine_alb_sg.id]
  subnets            = data.aws_subnets.public_subnets.ids

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "affine_tg" {
  name        = "affine-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.vpc_affine.id
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 29
    healthy_threshold   = 2
    unhealthy_threshold = 4
  }
}



resource "aws_lb_listener" "affine_listener_http" {
  load_balancer_arn = aws_lb.affine_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.affine_tg.arn
  }
}

# resource "aws_lb_listener" "n8n_listener_https" {
#   load_balancer_arn = aws_lb.n8n_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate.n8n_cert.arn
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.n8n_tg.arn
#   }
# }


resource "aws_security_group" "affine_alb_sg" {
  name   = "affine-alb-sg"
  vpc_id = data.aws_vpc.vpc_affine.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "affine" {
  name = "/ecs/affine"

  tags = {
    Environment = "dev"
    Application = "affine"
  }
}
module "tagging" {
  source = "D:/work projects/tagging"
  region = "eu-west-3"
  gitlab-project-name = "ecs-affine"
  project       = "affine"
  team = "devops"
}