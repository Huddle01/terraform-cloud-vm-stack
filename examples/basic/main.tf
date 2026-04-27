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

  name_prefix    = "demo"
  region         = var.region
  flavor_name    = var.flavor_name
  image_name     = var.image_name
  ssh_public_key = var.ssh_public_key

  ingress_rules = [
    # NOTE: SSH is open to all IPs for ease of testing. Restrict to your IP in production (e.g. "203.0.113.0/32").
    { protocol = "tcp", port = 22, cidr = "0.0.0.0/0" },
    { protocol = "tcp", port = 80, cidr = "0.0.0.0/0" },
    { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" }
  ]
}

output "public_ipv4" {
  value = module.vm_stack.public_ipv4
}
