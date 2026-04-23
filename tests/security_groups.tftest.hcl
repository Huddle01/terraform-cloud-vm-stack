# Unit tests for security group and firewall rule creation.
# Run with: terraform test -test-directory=tests
# Requires Terraform >= 1.7 (mock_provider support).

mock_provider "huddle" {}

variables {
  name_prefix    = "test"
  region         = "eu2"
  flavor_name    = "anton-2"
  image_name     = "ubuntu-22.04"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyDataForTesting user@host"
  create_network = false
  network_id     = "net-000"
}

# ── Security group ────────────────────────────────────────────────────────────

run "security_group_always_created" {
  command = plan

  assert {
    condition     = huddle_cloud_security_group.this != null
    error_message = "A security group should always be created."
  }
}

run "security_group_name_uses_prefix" {
  command = plan
  variables {
    name_prefix = "prod"
  }

  assert {
    condition     = huddle_cloud_security_group.this.name == "prod-sg"
    error_message = "Security group name must follow the pattern '<name_prefix>-sg'."
  }
}

run "security_group_region_matches_input" {
  command = plan

  assert {
    condition     = huddle_cloud_security_group.this.region == "eu2"
    error_message = "Security group region should match the region variable."
  }
}

# ── Ingress rules ─────────────────────────────────────────────────────────────

run "no_ingress_rules_created_by_default" {
  command = plan

  assert {
    condition     = length(huddle_cloud_security_group_rule.ingress) == 0
    error_message = "No ingress rules should be created when ingress_rules is empty."
  }
}

run "ingress_rule_count_matches_input" {
  command = plan
  variables {
    ingress_rules = [
      { protocol = "tcp", port = 22, cidr = "10.0.0.0/8" },
      { protocol = "tcp", port = 80, cidr = "0.0.0.0/0" },
      { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
    ]
  }

  assert {
    condition     = length(huddle_cloud_security_group_rule.ingress) == 3
    error_message = "Expected exactly 3 ingress rules to be created."
  }
}

run "ingress_rule_direction_is_ingress" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "tcp", port = 80, cidr = "0.0.0.0/0" }]
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.ingress)[0].direction == "ingress"
    error_message = "Ingress rule direction must be 'ingress'."
  }
}

run "ingress_rule_ether_type_is_ipv4" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "tcp", port = 80, cidr = "0.0.0.0/0" }]
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.ingress)[0].ether_type == "IPv4"
    error_message = "Ingress rule ether_type must be 'IPv4'."
  }
}

run "ingress_rule_attributes_match_input" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "udp", port = 53, cidr = "192.168.0.0/16" }]
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.ingress)[0].protocol == "udp"
    error_message = "Ingress rule protocol should match the input."
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.ingress)[0].port_range_min == 53
    error_message = "Ingress rule port_range_min should match the input port."
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.ingress)[0].port_range_max == 53
    error_message = "Ingress rule port_range_max should match the input port."
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.ingress)[0].remote_ip_prefix == "192.168.0.0/16"
    error_message = "Ingress rule remote_ip_prefix should match the input CIDR."
  }
}

run "ingress_single_port_min_equals_max" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "tcp", port = 8080, cidr = "0.0.0.0/0" }]
  }

  assert {
    condition = (
      values(huddle_cloud_security_group_rule.ingress)[0].port_range_min ==
      values(huddle_cloud_security_group_rule.ingress)[0].port_range_max
    )
    error_message = "port_range_min and port_range_max must be equal (single-port rules only)."
  }
}

# ── Egress rules ──────────────────────────────────────────────────────────────

run "no_egress_rules_created_by_default" {
  command = plan

  assert {
    condition     = length(huddle_cloud_security_group_rule.egress) == 0
    error_message = "No egress rules should be created when egress_rules is empty."
  }
}

run "egress_rule_count_matches_input" {
  command = plan
  variables {
    egress_rules = [
      { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
      { protocol = "udp", port = 123, cidr = "0.0.0.0/0" },
    ]
  }

  assert {
    condition     = length(huddle_cloud_security_group_rule.egress) == 2
    error_message = "Expected exactly 2 egress rules to be created."
  }
}

run "egress_rule_direction_is_egress" {
  command = plan
  variables {
    egress_rules = [{ protocol = "tcp", port = 443, cidr = "0.0.0.0/0" }]
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.egress)[0].direction == "egress"
    error_message = "Egress rule direction must be 'egress'."
  }
}

run "egress_rule_ether_type_is_ipv4" {
  command = plan
  variables {
    egress_rules = [{ protocol = "tcp", port = 443, cidr = "0.0.0.0/0" }]
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.egress)[0].ether_type == "IPv4"
    error_message = "Egress rule ether_type must be 'IPv4'."
  }
}

run "egress_rule_attributes_match_input" {
  command = plan
  variables {
    egress_rules = [{ protocol = "tcp", port = 443, cidr = "10.0.0.0/8" }]
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.egress)[0].protocol == "tcp"
    error_message = "Egress rule protocol should match the input."
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.egress)[0].port_range_min == 443
    error_message = "Egress rule port_range_min should match the input port."
  }

  assert {
    condition     = values(huddle_cloud_security_group_rule.egress)[0].remote_ip_prefix == "10.0.0.0/8"
    error_message = "Egress rule remote_ip_prefix should match the input CIDR."
  }
}

# ── Ingress and egress coexist ────────────────────────────────────────────────

run "ingress_and_egress_rules_coexist" {
  command = plan
  variables {
    ingress_rules = [
      { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
    ]
    egress_rules = [
      { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
      { protocol = "udp", port = 53, cidr = "0.0.0.0/0" },
    ]
  }

  assert {
    condition     = length(huddle_cloud_security_group_rule.ingress) == 1
    error_message = "Expected 1 ingress rule."
  }

  assert {
    condition     = length(huddle_cloud_security_group_rule.egress) == 2
    error_message = "Expected 2 egress rules."
  }
}
