# Unit tests for network creation conditional logic and resource naming.
# Run with: terraform test -test-directory=tests
# Requires Terraform >= 1.7 (mock_provider support).

mock_provider "huddle" {}

variables {
  name_prefix    = "test"
  region         = "eu2"
  flavor_name    = "anton-2"
  image_name     = "ubuntu-22.04"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyDataForTesting user@host"
}

# ── Network creation toggled on ───────────────────────────────────────────────

run "creates_one_network_when_enabled" {
  command = plan
  variables {
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
  }

  assert {
    condition     = length(huddle_cloud_network.this) == 1
    error_message = "Expected exactly one network resource when create_network is true."
  }
}

run "network_name_uses_prefix" {
  command = plan
  variables {
    name_prefix         = "myapp"
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
  }

  assert {
    condition     = huddle_cloud_network.this[0].name == "myapp-network"
    error_message = "Network name must follow the pattern '<name_prefix>-network'."
  }
}

run "network_region_matches_input" {
  command = plan
  variables {
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
  }

  assert {
    condition     = huddle_cloud_network.this[0].region == "eu2"
    error_message = "Network region should match the region variable."
  }
}

run "network_dhcp_enabled_by_default" {
  command = plan
  variables {
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
  }

  assert {
    condition     = huddle_cloud_network.this[0].enable_dhcp == true
    error_message = "DHCP should be enabled by default."
  }
}

run "network_no_gateway_false_by_default" {
  command = plan
  variables {
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
  }

  assert {
    condition     = huddle_cloud_network.this[0].no_gateway == false
    error_message = "no_gateway should be false by default."
  }
}

# ── Network creation toggled off ──────────────────────────────────────────────

run "skips_network_when_disabled" {
  command = plan
  variables {
    create_network = false
    network_id     = "net-existing-abc123"
  }

  assert {
    condition     = length(huddle_cloud_network.this) == 0
    error_message = "Expected no network resource when create_network is false."
  }
}

run "instance_uses_provided_network_when_disabled" {
  command = plan
  variables {
    create_network = false
    network_id     = "net-existing-abc123"
  }

  assert {
    condition     = huddle_cloud_instance.this.network_id == "net-existing-abc123"
    error_message = "Instance should use the provided network_id when create_network is false."
  }
}

# ── Precondition: required network vars when create_network = true ────────────

run "precondition_pool_cidr_missing_fails" {
  command = plan
  variables {
    create_network      = true
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
    # pool_cidr intentionally omitted — precondition should fire
  }

  expect_failures = [huddle_cloud_network.this[0]]
}

run "precondition_primary_subnet_cidr_missing_fails" {
  command = plan
  variables {
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_size = 24
    # primary_subnet_cidr intentionally omitted
  }

  expect_failures = [huddle_cloud_network.this[0]]
}

run "precondition_primary_subnet_size_missing_fails" {
  command = plan
  variables {
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    # primary_subnet_size intentionally omitted
  }

  expect_failures = [huddle_cloud_network.this[0]]
}

# ── Instance resource naming ──────────────────────────────────────────────────

run "instance_name_uses_prefix" {
  command = plan
  variables {
    name_prefix    = "staging"
    create_network = false
    network_id     = "net-000"
  }

  assert {
    condition     = huddle_cloud_instance.this.name == "staging-vm"
    error_message = "Instance name must follow the pattern '<name_prefix>-vm'."
  }
}

run "keypair_name_uses_prefix" {
  command = plan
  variables {
    name_prefix    = "staging"
    create_network = false
    network_id     = "net-000"
  }

  assert {
    condition     = huddle_cloud_keypair.this.name == "staging-key"
    error_message = "Keypair name must follow the pattern '<name_prefix>-key'."
  }
}

# ── Instance defaults ─────────────────────────────────────────────────────────

run "assign_public_ip_true_by_default" {
  command = plan
  variables {
    create_network = false
    network_id     = "net-000"
  }

  assert {
    condition     = huddle_cloud_instance.this.assign_public_ip == true
    error_message = "assign_public_ip should default to true."
  }
}

run "power_state_active_by_default" {
  command = plan
  variables {
    create_network = false
    network_id     = "net-000"
  }

  assert {
    condition     = huddle_cloud_instance.this.power_state == "active"
    error_message = "power_state should default to 'active'."
  }
}

run "boot_disk_size_30_by_default" {
  command = plan
  variables {
    create_network = false
    network_id     = "net-000"
  }

  assert {
    condition     = huddle_cloud_instance.this.boot_disk_size == 30
    error_message = "boot_disk_size should default to 30."
  }
}

run "custom_boot_disk_size_is_passed_to_instance" {
  command = plan
  variables {
    create_network = false
    network_id     = "net-000"
    boot_disk_size = 80
  }

  assert {
    condition     = huddle_cloud_instance.this.boot_disk_size == 80
    error_message = "Custom boot_disk_size should be forwarded to the instance resource."
  }
}

run "assign_public_ip_false_is_passed_to_instance" {
  command = plan
  variables {
    create_network   = false
    network_id       = "net-000"
    assign_public_ip = false
  }

  assert {
    condition     = huddle_cloud_instance.this.assign_public_ip == false
    error_message = "assign_public_ip = false should be forwarded to the instance resource."
  }
}

run "flavor_name_is_passed_to_instance" {
  command = plan
  variables {
    create_network = false
    network_id     = "net-000"
    flavor_name    = "anton-8"
  }

  assert {
    condition     = huddle_cloud_instance.this.flavor_name == "anton-8"
    error_message = "flavor_name should be forwarded to the instance resource."
  }
}

run "image_name_is_passed_to_instance" {
  command = plan
  variables {
    create_network = false
    network_id     = "net-000"
    image_name     = "debian-12"
  }

  assert {
    condition     = huddle_cloud_instance.this.image_name == "debian-12"
    error_message = "image_name should be forwarded to the instance resource."
  }
}

run "region_is_passed_to_instance" {
  command = plan
  variables {
    region         = "us1"
    create_network = false
    network_id     = "net-000"
  }

  assert {
    condition     = huddle_cloud_instance.this.region == "us1"
    error_message = "region should be forwarded to the instance resource."
  }
}

# ── Network options ───────────────────────────────────────────────────────────

run "no_gateway_true_is_forwarded" {
  command = plan
  variables {
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
    no_gateway          = true
  }

  assert {
    condition     = huddle_cloud_network.this[0].no_gateway == true
    error_message = "no_gateway = true should be forwarded to the network resource."
  }
}

run "enable_dhcp_false_is_forwarded" {
  command = plan
  variables {
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
    enable_dhcp         = false
  }

  assert {
    condition     = huddle_cloud_network.this[0].enable_dhcp == false
    error_message = "enable_dhcp = false should be forwarded to the network resource."
  }
}

run "network_region_forwarded_when_create_network_true" {
  command = plan
  variables {
    region              = "us1"
    create_network      = true
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
  }

  assert {
    condition     = huddle_cloud_network.this[0].region == "us1"
    error_message = "region should be forwarded to the network resource."
  }
}

# ── Precondition: network_id required when create_network = false ─────────────

run "precondition_network_id_missing_fails" {
  command = plan
  variables {
    create_network = false
    network_id     = null
  }

  expect_failures = [huddle_cloud_instance.this]
}
