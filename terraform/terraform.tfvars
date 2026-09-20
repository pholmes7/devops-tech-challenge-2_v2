aws_region   = "us-east-2"
project_name = "devops-tech-challenge-2"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "us-east-2a",
  "us-east-2b"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24"
]

eks_cluster_name = "tech-challenge-2-eks"

node_instance_type = "t3.small"

node_min_size     = 1
node_desired_size = 2
node_max_size     = 4