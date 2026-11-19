# Provisionamento de Infraestrutura na AWS com Terraform (Atividade Unidade 3)

Este projeto utiliza **Terraform (Infrastructure as Code)** para provisionar de forma automatizada uma arquitetura web completa na AWS composta por:
1. **Application Load Balancer (ALB)** para distribuição e entrada de tráfego HTTP.
2. **Instância EC2 (Amazon Linux 2023)** executando um servidor web Apache configurado via `user_data`.
3. **Banco de Dados Relacional (Amazon RDS - MySQL 8.0)** isolado em rede privada.
4. **Security Groups** encadeados garantindo o princípio do menor privilégio (`Internet -> ALB -> EC2 -> RDS`).

## Pré-requisitos
- Conta ativa na AWS (recomenda-se uso de credenciais IAM com permissões para EC2, VPC, ELB e RDS).
- **AWS CLI** instalado e configurado (`aws configure`).
- **Terraform** instalado (versão >= 1.5.0).

## Como Executar e Implantar

1. **Inicializar o diretório e baixar o provider da AWS:**
   ```bash
   terraform init
  
1.1 Validar a sintaxe e visualizar o plano de execução:

Bash
terraform plan

2. Aplicar e criar os recursos na AWS:

Bash
terraform apply -auto-approve
(A criação do banco de dados RDS leva aproximadamente 4 a 6 minutos).

3. Testar a Arquitetura:

* Ao final do comando apply, copie a URL exibida no output load_balancer_dns.
* Cole no navegador para visualizar a página HTML servida pela instância EC2 através do Load Balancer.

4. Limpeza dos Recursos (Evitar Custos)
Após concluir a gravação e os testes, remova todos os recursos criados com o comando:

Bash
terraform destroy -auto-approve
