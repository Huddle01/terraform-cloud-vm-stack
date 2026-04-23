terraform {
  required_version = ">= 1.2"
  required_providers {
    huddle = {
      source  = "huddle01/cloud"
      version = "0.3.1"
    }
  }
}

provider "huddle" {
  api_key  = var.api_key
  region   = var.region
  base_url = var.base_url
}

module "vm_stack" {
  source = "../../../"

  name_prefix         = var.name_prefix
  region              = var.region
  flavor_name         = var.flavor_name
  image_name          = var.image_name
  ssh_public_key      = var.ssh_public_key
  assign_public_ip    = var.assign_public_ip
  power_state         = var.power_state
  create_network      = var.create_network
  network_id          = var.network_id
  pool_cidr           = var.pool_cidr
  primary_subnet_cidr = var.primary_subnet_cidr
  primary_subnet_size = var.primary_subnet_size
  no_gateway          = var.no_gateway
  enable_dhcp         = var.enable_dhcp
  ingress_rules       = var.ingress_rules
  egress_rules        = var.egress_rules
}

output "instance_id" { value = module.vm_stack.instance_id }
output "instance_name" { value = module.vm_stack.instance_name }
output "instance_status" { value = module.vm_stack.instance_status }
output "network_id" { value = module.vm_stack.network_id }
output "security_group_id" { value = module.vm_stack.security_group_id }

output "public_ipv4" {
  value     = module.vm_stack.public_ipv4
  sensitive = true
}

output "private_ipv4" {
  value     = module.vm_stack.private_ipv4
  sensitive = true
}
