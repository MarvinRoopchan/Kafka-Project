############################################################
# Terraform & Provider
############################################################

provider "aws" {
  region = "us-east-1"
}

############################################################
# VPC
############################################################
resource "aws_vpc" "marvin" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "marvin-vpc" }
}

############################################################
# Internet Gateway
############################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.marvin.id
  tags   = { Name = "marvin-igw" }
}

############################################################
# Subnets (explicit, one per AZ)
############################################################
# Public
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.marvin.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "marvin-public-1a" }
}
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.marvin.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "marvin-public-1b" }
}
resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.marvin.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true
  tags                    = { Name = "marvin-public-1c" }
}

# Private
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.marvin.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "marvin-private-1a" }
}
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.marvin.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "marvin-private-1b" }
}
resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.marvin.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1c"
  tags              = { Name = "marvin-private-1c" }
}

############################################################
# EIPs + NAT Gateways (one per public subnet)
############################################################
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags   = { Name = "marvin-nat-eip-a" }
}
resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags   = { Name = "marvin-nat-eip-b" }
}
resource "aws_eip" "nat_c" {
  domain = "vpc"
  tags   = { Name = "marvin-nat-eip-c" }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  tags          = { Name = "marvin-nat-a" }
  depends_on    = [aws_internet_gateway.igw]
}
resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
  tags          = { Name = "marvin-nat-b" }
  depends_on    = [aws_internet_gateway.igw]
}
resource "aws_nat_gateway" "nat_c" {
  allocation_id = aws_eip.nat_c.id
  subnet_id     = aws_subnet.public_c.id
  tags          = { Name = "marvin-nat-c" }
  depends_on    = [aws_internet_gateway.igw]
}

############################################################
# Route Tables & Associations
############################################################
# Public RT (shared)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.marvin.id
  tags   = { Name = "marvin-public-rt" }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "pub_a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_a.id
}
resource "aws_route_table_association" "pub_b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_b.id
}
resource "aws_route_table_association" "pub_c" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_c.id
}

# Private RTs (one per AZ → each uses its AZ’s NAT)
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.marvin.id
  tags   = { Name = "marvin-private-rt-a" }
}
resource "aws_route" "priv_a_nat" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a.id
}
resource "aws_route_table_association" "priv_a" {
  route_table_id = aws_route_table.private_a.id
  subnet_id      = aws_subnet.private_a.id
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.marvin.id
  tags   = { Name = "marvin-private-rt-b" }
}
resource "aws_route" "priv_b_nat" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_b.id
}
resource "aws_route_table_association" "priv_b" {
  route_table_id = aws_route_table.private_b.id
  subnet_id      = aws_subnet.private_b.id
}

resource "aws_route_table" "private_c" {
  vpc_id = aws_vpc.marvin.id
  tags   = { Name = "marvin-private-rt-c" }
}
resource "aws_route" "priv_c_nat" {
  route_table_id         = aws_route_table.private_c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_c.id
}
resource "aws_route_table_association" "priv_c" {
  route_table_id = aws_route_table.private_c.id
  subnet_id      = aws_subnet.private_c.id
}

############################################################
# Security Groups (multi-line ingress/egress)
############################################################
# ALB SG – internet-facing 80/443
resource "aws_security_group" "alb_sg" {
  name        = "marvin-alb-sg"
  description = "Internet-facing ALB SG"
  vpc_id      = aws_vpc.marvin.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
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

  tags = { Name = "marvin-alb-sg" }
}

# Worker nodes SG – allow ALB -> NodePort, intra-VPC traffic
resource "aws_security_group" "worker_sg" {
  name        = "marvin-eks-worker-sg"
  description = "EKS workers"
  vpc_id      = aws_vpc.marvin.id

  # ALB to NodePorts
  ingress {
    description     = "ALB to NodePort range"
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow cluster/pod traffic within VPC (simplified)
  ingress {
    description = "intra-VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.marvin.cidr_block]
  }

  # Egress anywhere (pods need outbound to MSK/RDS/Internet via NAT)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "marvin-eks-worker-sg" }
}

# RDS SG – only from worker nodes
resource "aws_security_group" "postgres_sg" {
  name        = "marvin-rds-pg-sg"
  description = "Postgres access from EKS workers"
  vpc_id      = aws_vpc.marvin.id

  ingress {
    description     = "Postgres 5432 from workers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "marvin-rds-pg-sg" }
}

# MSK SG – only from worker nodes
resource "aws_security_group" "msk_sg" {
  name        = "marvin-msk-sg"
  description = "Kafka brokers access from EKS workers"
  vpc_id      = aws_vpc.marvin.id

  ingress {
    description     = "Kafka 9092 from workers"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "marvin-msk-sg" }
}

############################################################
# RDS PostgreSQL (private)
############################################################
resource "aws_db_subnet_group" "pg_subnets" {
  name = "marvin-pg-subnets"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]
  tags = { Name = "marvin-pg-subnets" }
}


resource "aws_db_instance" "postgres" {
  identifier        = "marvin-db"
  engine            = "postgres"
  engine_version    = "17.6"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  username = "marvin_user"
  password = "Rocky659803!"

  db_subnet_group_name   = aws_db_subnet_group.pg_subnets.name
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true

  tags = { Name = "marvin-rds" }
}

############################################################
# MSK (Kafka) – 3 brokers, private
############################################################
resource "aws_msk_cluster" "kafka" {
  cluster_name           = "marvin-kafka"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type = "kafka.t3.small"
    client_subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.private_c.id
    ]
    security_groups = [aws_security_group.msk_sg.id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT" # demo simplicity; use TLS in prod
      in_cluster    = true
    }
  }

  tags = { Name = "marvin-msk" }
}

############################################################
# EKS Cluster + Node Group (via Launch Template)
############################################################
# Cluster Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "marvin-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# Cluster
resource "aws_eks_cluster" "eks" {
  name     = "marvin-eks"
  version  = "1.29"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
      aws_subnet.private_c.id
    ]
    security_group_ids = [aws_security_group.worker_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller
  ]

  tags = { Name = "marvin-eks" }
}

# Node Role
resource "aws_iam_role" "eks_node_role" {
  name = "marvin-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_ecr_ro" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Launch Template for worker nodes so they use our worker_sg
resource "aws_launch_template" "eks_lt" {
  name_prefix            = "marvin-eks-lt-"
  update_default_version = true

  network_interfaces {
    security_groups = [aws_security_group.worker_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "marvin-eks-worker" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Node Group
resource "aws_eks_node_group" "ng" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "marvin-ng"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 2
  }

  launch_template {
    id      = aws_launch_template.eks_lt.id
    version = "$Latest"
  }

  ami_type       = "AL2_x86_64"
  instance_types = ["t3.medium"]

  tags = { Name = "marvin-ng" }
}

############################################################
# Outputs
############################################################
output "vpc_id" {
  value = aws_vpc.marvin.id
}

output "public_subnets" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id, aws_subnet.public_c.id]
}

output "private_subnets" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.private_c.id]
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "rds_master_user" {
  value = aws_db_instance.postgres.username
}


output "msk_bootstrap_brokers" {
  value = aws_msk_cluster.kafka.bootstrap_brokers
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

