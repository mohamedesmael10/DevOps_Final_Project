# Define the VPC
module "vpc" {
  source     = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
  vpc_name   = "my-vpc-Terraform"
}

# Public Subnets
module "public_subnet_1" {
  source                = "./modules/subnet"
  vpc_id                = module.vpc.vpc_id
  subnet_cidr           = "10.0.1.0/24"
  availability_zone     = "us-east-1a"
  map_public_ip_on_launch = true
  subnet_name           = "public-subnet-1"
  depends_on            = [module.vpc]
}

module "public_subnet_2" {
  source                = "./modules/subnet"
  vpc_id                = module.vpc.vpc_id
  subnet_cidr           = "10.0.3.0/24"
  availability_zone     = "us-east-1b"
  map_public_ip_on_launch = true
  subnet_name           = "public-subnet-2"
  depends_on            = [module.vpc]
}

# Private Subnets
module "private_subnet_1" {
  source                = "./modules/subnet"
  vpc_id                = module.vpc.vpc_id
  subnet_cidr           = "10.0.2.0/24"
  availability_zone     = "us-east-1a"
  map_public_ip_on_launch = false
  subnet_name           = "private-subnet-1"
  depends_on            = [module.vpc]
}

module "private_subnet_2" {
  source                = "./modules/subnet"
  vpc_id                = module.vpc.vpc_id
  subnet_cidr           = "10.0.4.0/24"
  availability_zone     = "us-east-1b"
  map_public_ip_on_launch = false
  subnet_name           = "private-subnet-2"
  depends_on            = [module.vpc]
}

# Internet Gateway
module "internet_gateway" {
  source     = "./modules/internet_gateway"
  vpc_id     = module.vpc.vpc_id
  name       = "${var.project_name}-igw"
  depends_on = [module.vpc]
}

# Public Route Table
module "public_route_table" {
  source              = "./modules/public_route_table"
  vpc_id              = module.vpc.vpc_id
  internet_gateway_id = module.internet_gateway.internet_gateway_id
  subnet_ids          = [module.public_subnet_1.subnet_id, module.public_subnet_2.subnet_id]
  name                = "${var.project_name}-public-rt"
  depends_on          = [module.vpc, module.internet_gateway, module.public_subnet_1, module.public_subnet_2]
}

# NAT Gateway
module "nat_gateway" {
  source            = "./modules/nat_gateway"
  public_subnet_id  = module.public_subnet_1.subnet_id
  name              = "${var.project_name}-nat-gw"
  depends_on        = [module.public_subnet_1, module.internet_gateway , module.public_subnet_2]
}

# Private Route Table
module "private_route_table" {
  source           = "./modules/private_route_table"
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = [module.private_subnet_1.subnet_id, module.private_subnet_2.subnet_id]
  nat_gateway_id   = module.nat_gateway.nat_gw_id
  name             = "${var.project_name}-private-rt"
  depends_on       = [module.vpc, module.private_subnet_1, module.private_subnet_2, module.nat_gateway]
}

# Security Groups
module "bastion_security_group" {
  source        = "./modules/security_group"
  vpc_id        = module.vpc.vpc_id
  name          = "${var.project_name}-bastion-sg"
  description   = "Security group for Bastion host"
  ingress_rules = var.bastion_ingress_rules
  depends_on    = [module.vpc]
}

module "nginx_security_group" {
  source        = "./modules/security_group"
  vpc_id        = module.vpc.vpc_id
  name          = "${var.project_name}-nginx-sg"
  description   = "Security group for Nginx"
  ingress_rules = var.nginx_ingress_rules
  depends_on    = [module.vpc]
}

module "jenkins_portainer_sg" {
  source        = "./modules/security_group"
  vpc_id        = module.vpc.vpc_id
  name          = "${var.project_name}-jenkins-portainer-sg"
  description   = "Security group for Jenkins and Portainer"
  ingress_rules = var.custom_ingress_rules
  depends_on    = [module.vpc]
}

# Public Instances
module "public_instances" {
  source                      = "./modules/instance"
  instance_count               = 1
  ami_id                       = var.ami_id
  associate_public_ip_address  = true
  instance_type                = var.instance_type
  subnet_ids                   = [module.public_subnet_1.subnet_id]
  security_group_ids           = [
    module.nginx_security_group.security_group_id, 
    module.jenkins_portainer_sg.security_group_id, 
    module.bastion_security_group.security_group_id
  ]
  key_name                     = var.key_name
  instance_name                = "public"
  depends_on      = [module.public_subnet_1, module.public_subnet_2, module.nginx_security_group, module.bastion_security_group]
}

# Private Instances (using the new module for provisioning)
module "private_instances" {
  source                       = "./modules/instance"
  instance_count               = 2
  ami_id                       = var.ami_id
  instance_type                = var.instance_type
  subnet_ids                   = [
    module.private_subnet_1.subnet_id, 
    module.private_subnet_2.subnet_id
  ]
  security_group_ids           = [
    module.nginx_security_group.security_group_id, 
    module.jenkins_portainer_sg.security_group_id, 
    module.bastion_security_group.security_group_id
  ]
  instance_name                = "private-instance"
  #user_data = var.user_data
  key_name                     = var.key_name
  key_path                     = var.key_path
  associate_public_ip_address  = false
  instance_user                = "ubuntu"  # SSH user for private instances
  bastion_user                 = "ubuntu"  # SSH user for bastion host
  ansible_source_directory     = "./ansible"  # Path to Ansible files
  
  bastion_public_ip = module.public_instances.public_ips[0]  # Get the first public IP
  depends_on      = [module.private_subnet_1, module.private_subnet_2, module.bastion_security_group, module.nginx_security_group , module.nat_gateway]
}

# Load Balancer
module "load_balancer" {
  source             = "./modules/load_balancer"
  lb_name            = "my-load-balancer"
  internal           = false
  subnet_ids         = [module.public_subnet_1.subnet_id, module.public_subnet_2.subnet_id]
  security_group_ids = [
    module.nginx_security_group.security_group_id, 
    module.jenkins_portainer_sg.security_group_id, 
    module.bastion_security_group.security_group_id
  ]
  target_group_name  = "my-target-group"
  target_group_port  = 80
  target_group_protocol = "HTTP"
  vpc_id             = module.vpc.vpc_id
  listener_port      = 80
  listener_protocol  = "HTTP"
  instance_count     = 2
  instance_ids       = module.private_instances.instance_ids
  depends_on         = [module.private_subnet_1, module.private_subnet_2, module.nginx_security_group, module.private_instances , module.public_subnet_1.subnet_id, module.public_subnet_2.subnet_id]
}

# Key Pair
module "key" {
  source       = "./modules/key_pair"
  encrypt_kind = "RSA"
  encrypt_bits = 4096
  depends_on   = [module.vpc]
}


# module "ansible_provisioning" {
#   source          = "./modules/ansible"
#   instance_ips    = module.private_instances.private_ips  
#   ansible_user    = "ubuntu"
#   bastion_user    = "ubuntu"   
#   private_key_path = "./key-pair.pem"  
#   playbook_path   = "./ansible/playbook.yml"  
#   bastion_public_ip = module.public_instances.public_ips[0]
#   depends_on      = [module.private_subnet_1, module.private_subnet_2, module.key , module.public_instances , module.private_instances , module.nat_gateway , module.jenkins_portainer_sg , module.nginx_security_group , module.bastion_security_group]

# }