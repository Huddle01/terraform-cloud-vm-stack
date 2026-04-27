terraform {
  required_providers {
    huddle = {
      source  = "huddle01/cloud"
      version = ">= 0.3.2"
    }
  }
}

provider "huddle" {
  api_key = var.huddle_api_key
  region  = var.region
}

module "vm_stack" {
  source = "../../"

  name_prefix    = "internal"
  region         = var.region
  flavor_name    = var.flavor_name
  image_name     = var.image_name
  ssh_public_key = var.ssh_public_key

  # No public IP — reachable only from within the private network or via VPN.
  assign_public_ip = false

  pool_cidr           = "10.0.0.0/8"
  primary_subnet_cidr = "10.0.2.0/24"
  primary_subnet_size = 24

  # No ingress rules — block all inbound traffic from outside the network.
  # Add rules here if the VM needs to accept connections from within the subnet.

  # Restrict egress to HTTPS and DNS only.
  egress_rules = [
    { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
    { protocol = "udp", port = 53, cidr = "0.0.0.0/0" },
  ]
}

output "private_ipv4" {
  value     = module.vm_stack.private_ipv4
  sensitive = true
}

output "instance_id" {
  value = module.vm_stack.instance_id
}
