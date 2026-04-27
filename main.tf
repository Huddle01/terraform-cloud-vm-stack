terraform {
  required_version = ">= 1.2"
  required_providers {
    huddle = {
      source  = "huddle01/cloud"
      version = ">= 0.3.2"
    }
  }
}

resource "huddle_cloud_network" "this" {
  count               = var.create_network ? 1 : 0
  name                = "${var.name_prefix}-network"
  region              = var.region
  pool_cidr           = var.pool_cidr
  primary_subnet_cidr = var.primary_subnet_cidr
  primary_subnet_size = var.primary_subnet_size
  no_gateway          = var.no_gateway
  enable_dhcp         = var.enable_dhcp

  lifecycle {
    precondition {
      condition     = var.pool_cidr != null
      error_message = "pool_cidr is required when create_network is true."
    }
    precondition {
      condition     = var.primary_subnet_cidr != null
      error_message = "primary_subnet_cidr is required when create_network is true."
    }
    precondition {
      condition     = var.primary_subnet_size != null
      error_message = "primary_subnet_size is required when create_network is true."
    }
  }
}

resource "huddle_cloud_security_group" "this" {
  name        = "${var.name_prefix}-sg"
  description = "Managed by terraform vm-stack module"
  region      = var.region
}

resource "huddle_cloud_security_group_rule" "ingress" {
  for_each          = { for i, rule in var.ingress_rules : i => rule }
  security_group_id = huddle_cloud_security_group.this.id
  region            = var.region
  direction         = "ingress"
  ether_type        = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
}

resource "huddle_cloud_security_group_rule" "egress" {
  for_each          = { for i, rule in var.egress_rules : i => rule }
  security_group_id = huddle_cloud_security_group.this.id
  region            = var.region
  direction         = "egress"
  ether_type        = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = each.value.cidr
}

resource "huddle_cloud_keypair" "this" {
  name       = "${var.name_prefix}-key"
  public_key = var.ssh_public_key
}

locals {
  network_id = var.create_network ? huddle_cloud_network.this[0].id : var.network_id
}

resource "huddle_cloud_instance" "this" {
  name                 = "${var.name_prefix}-vm"
  region               = var.region
  flavor_name          = var.flavor_name
  image_name           = var.image_name
  boot_disk_size       = var.boot_disk_size
  key_names            = [huddle_cloud_keypair.this.name]
  security_group_names = [huddle_cloud_security_group.this.name]
  assign_public_ip     = var.assign_public_ip
  network_id           = local.network_id
  power_state          = var.power_state

  depends_on = [huddle_cloud_network.this]

  lifecycle {
    precondition {
      condition     = var.create_network || var.network_id != null
      error_message = "network_id must be set when create_network is false."
    }
  }
}
