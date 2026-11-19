terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Norte da Virgínia (menor custo e maior disponibilidade)
}

# ==============================================================================
# 1. REDE E SUB-REDES (Utilizando a VPC Padrão da conta AWS)
# ==============================================================================
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Busca a AMI mais recente do Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# ==============================================================================
# 2. SECURITY GROUPS (Regras de Firewall e Dependências de Segurança)
# ==============================================================================

# SG do Application Load Balancer (Recebe tráfego HTTP da Internet)
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Permite trafego HTTP de entrada para o Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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

# SG da Instância EC2 (Recebe tráfego APENAS vindo do Load Balancer)
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Permite trafego HTTP vindo do ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG do Banco de Dados RDS (Recebe tráfego MySQL APENAS da instância EC2)
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Permite acesso MySQL (3306) apenas da instancia EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# 3. INSTÂNCIA EC2 (Servidor de Aplicação)
# ==============================================================================
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro" # Elegível ao Free Tier
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Script de inicialização para instalar servidor web Apache e exibir página de teste
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Infraestrutura Provisionada via Terraform!</h1><p>Instancia EC2 respondendo atras do Application Load Balancer.</p>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "Servidor-Web-Atividade3"
  }
}

# ==============================================================================
# 4. APPLICATION LOAD BALANCER (ALB) E TARGET GROUP
# ==============================================================================
resource "aws_lb" "app_lb" {
  name               = "app-load-balancer-ativ3"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "ALB-Atividade3"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group-ativ3"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Conecta a instância EC2 ao Target Group do Load Balancer
resource "aws_lb_target_group_attachment" "ec2_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web_server.id
  port             = 80
}

# Listener na porta 80 encaminhando requisições para o Target Group
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ==============================================================================
# 5. BANCO DE DADOS RELACIONAL (Amazon RDS - MySQL)
# ==============================================================================
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group-ativ3"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "RDS Subnet Group Atividade 3"
  }
}

resource "aws_db_instance" "database" {
  identifier             = "db-atividade3-mysql"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # Elegível ao Free Tier
  db_name                = "appdb"
  username               = "admin"
  password               = "SenhaForte123!" # Em produção, utilizar AWS Secrets Manager
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true # Facilita a destruição rápida após o teste
  publicly_accessible    = false

  tags = {
    Name = "RDS-MySQL-Atividade3"
  }
}

# ==============================================================================
# 6. SAÍDAS (OUTPUTS) PARA VALIDAÇÃO E TESTE
# ==============================================================================
output "load_balancer_dns" {
  description = "URL publica do Application Load Balancer para acessar a aplicacao"
  value       = "http://${aws_lb.app_lb.dns_name}"
}

output "ec2_instance_id" {
  description = "ID da instancia EC2 criada"
  value       = aws_instance.web_server.id
}

output "rds_endpoint" {
  description = "Endpoint de conexao do banco de dados RDS"
  value       = aws_db_instance.database.endpoint
}



