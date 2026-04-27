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

  name_prefix    = "app"
  region         = var.region
  flavor_name    = var.flavor_name
  image_name     = var.image_name
  ssh_public_key = var.ssh_public_key

  # Attach to an existing network instead of creating a new one.
  create_network = false
  network_id     = var.network_id

  ingress_rules = [
    # Restrict SSH to a known bastion / operator IP in production.
    { protocol = "tcp", port = 22, cidr = "0.0.0.0/0" },
    { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
  ]
}

output "public_ipv4" {
  value     = module.vm_stack.public_ipv4
  sensitive = true
}

output "instance_id" {
  value = module.vm_stack.instance_id
}
