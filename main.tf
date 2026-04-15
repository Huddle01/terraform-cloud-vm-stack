terraform {
  required_providers {
    huddle = {
      source = "huddle01/cloud"
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

resource "huddle_cloud_keypair" "this" {
  name       = "${var.name_prefix}-key"
  public_key = var.ssh_public_key
}

locals {
  network_id = var.create_network ? huddle_cloud_network.this[0].id : var.network_id
}

resource "huddle_cloud_instance" "this" {
  name                   = "${var.name_prefix}-vm"
  region                 = var.region
  flavor_id              = var.flavor_id
  image_id               = var.image_id
  boot_disk_size         = var.boot_disk_size
  additional_volume_size = var.additional_volume_size
  key_names              = [huddle_cloud_keypair.this.name]
  security_group_names   = [huddle_cloud_security_group.this.name]
  assign_public_ip       = var.assign_public_ip
  network_id             = local.network_id
  power_state            = var.power_state
}
