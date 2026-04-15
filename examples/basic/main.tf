provider "huddle" {
  api_key = var.huddle_api_key
  region  = var.region
}

module "vm_stack" {
  source = "../../"

  name_prefix    = "demo"
  region         = var.region
  flavor_id      = var.flavor_id
  image_id       = var.image_id
  ssh_public_key = var.ssh_public_key

  ingress_rules = [
    { protocol = "tcp", port = 22, cidr = "0.0.0.0/0" },
    { protocol = "tcp", port = 80, cidr = "0.0.0.0/0" },
    { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" }
  ]
}

output "public_ipv4" {
  value = module.vm_stack.public_ipv4
}
