terraform {
  required_providers {
    huddle = {
      source  = "huddle01/cloud"
      version = "~> 0.3"
    }
  }
}

provider "huddle" {
  api_key = var.huddle_api_key
  region  = var.region
}

# ── VM stack ─────────────────────────────────────────────────────────────────

module "vm_stack" {
  source = "../../"

  name_prefix    = "data-vm"
  region         = var.region
  flavor_name    = var.flavor_name
  image_name     = var.image_name
  ssh_public_key = var.ssh_public_key

  pool_cidr           = "10.0.0.0/8"
  primary_subnet_cidr = "10.0.3.0/24"
  primary_subnet_size = 24

  ingress_rules = [
    { protocol = "tcp", port = 22, cidr = "0.0.0.0/0" },
    { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
  ]
}

# ── Standalone data volume ────────────────────────────────────────────────────
# Managed independently of the instance lifecycle.
# Set delete_on_destroy = true only when the data can be permanently discarded.

resource "huddle_cloud_volume" "data" {
  name   = "data-vm-data"
  size   = var.volume_size
  region = var.region

  # Default: volume is retained when terraform destroy is run.
  # delete_on_destroy = false
}

# ── Volume attachment ─────────────────────────────────────────────────────────

resource "huddle_cloud_volume_attachment" "data" {
  volume_id   = huddle_cloud_volume.data.id
  instance_id = module.vm_stack.instance_id
  region      = var.region
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "public_ipv4" {
  value     = module.vm_stack.public_ipv4
  sensitive = true
}

output "instance_id" {
  value = module.vm_stack.instance_id
}

output "volume_id" {
  value       = huddle_cloud_volume.data.id
  description = "ID of the data volume. Retained on destroy unless delete_on_destroy = true."
}
