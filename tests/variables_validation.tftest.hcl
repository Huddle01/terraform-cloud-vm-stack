# Unit tests for variable validation rules.
# Run with: terraform test -test-directory=tests
# Requires Terraform >= 1.7 (mock_provider support).

mock_provider "huddle" {}

# ── Shared variable defaults ─────────────────────────────────────────────────
# Used as a base in each run block via variable overrides.
variables {
  name_prefix    = "test"
  region         = "eu2"
  flavor_name    = "anton-2"
  image_name     = "ubuntu-22.04"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyDataForTesting user@host"
  create_network = false
  network_id     = "net-000"
}

# ── ssh_public_key ────────────────────────────────────────────────────────────

run "ssh_key_ed25519_passes" {
  command = plan
}

run "ssh_key_rsa_passes" {
  command = plan
  variables {
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCFakeRSAKeyData user@host"
  }
}

run "ssh_key_ecdsa_passes" {
  command = plan
  variables {
    ssh_public_key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYFakeECDSAData user@host"
  }
}

run "ssh_key_invalid_format_fails" {
  command = plan
  variables {
    ssh_public_key = "not-a-valid-key"
  }
  expect_failures = [var.ssh_public_key]
}

run "ssh_key_empty_string_fails" {
  command = plan
  variables {
    ssh_public_key = ""
  }
  expect_failures = [var.ssh_public_key]
}

run "ssh_key_password_hash_fails" {
  command = plan
  variables {
    ssh_public_key = "$6$rounds=656000$fakehash"
  }
  expect_failures = [var.ssh_public_key]
}

# ── boot_disk_size ────────────────────────────────────────────────────────────

run "boot_disk_size_positive_passes" {
  command = plan
  variables {
    boot_disk_size = 50
  }
}

run "boot_disk_size_zero_fails" {
  command = plan
  variables {
    boot_disk_size = 0
  }
  expect_failures = [var.boot_disk_size]
}

run "boot_disk_size_negative_fails" {
  command = plan
  variables {
    boot_disk_size = -10
  }
  expect_failures = [var.boot_disk_size]
}

# ── power_state ───────────────────────────────────────────────────────────────

run "power_state_active_passes" {
  command = plan
  variables {
    power_state = "active"
  }
}

run "power_state_stopped_passes" {
  command = plan
  variables {
    power_state = "stopped"
  }
}

run "power_state_paused_passes" {
  command = plan
  variables {
    power_state = "paused"
  }
}

run "power_state_suspended_passes" {
  command = plan
  variables {
    power_state = "suspended"
  }
}

run "power_state_running_fails" {
  command = plan
  variables {
    power_state = "running"
  }
  expect_failures = [var.power_state]
}

run "power_state_on_fails" {
  command = plan
  variables {
    power_state = "on"
  }
  expect_failures = [var.power_state]
}

# ── network_id required when create_network = false ───────────────────────────

run "network_id_required_when_create_network_false_fails" {
  command = plan
  variables {
    create_network = false
    network_id     = null
  }
  expect_failures = [var.network_id]
}

# ── ingress_rules ─────────────────────────────────────────────────────────────

run "ingress_valid_rules_pass" {
  command = plan
  variables {
    ingress_rules = [
      { protocol = "tcp",  port = 22,  cidr = "10.0.0.0/8" },
      { protocol = "tcp",  port = 443, cidr = "0.0.0.0/0" },
      { protocol = "udp",  port = 53,  cidr = "192.168.1.0/24" },
      { protocol = "icmp", port = 1,   cidr = "0.0.0.0/0" },
    ]
  }
}

run "ingress_port_zero_fails" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "tcp", port = 0, cidr = "0.0.0.0/0" }]
  }
  expect_failures = [var.ingress_rules]
}

run "ingress_port_above_max_fails" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "tcp", port = 65536, cidr = "0.0.0.0/0" }]
  }
  expect_failures = [var.ingress_rules]
}

run "ingress_invalid_protocol_fails" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "http", port = 80, cidr = "0.0.0.0/0" }]
  }
  expect_failures = [var.ingress_rules]
}

run "ingress_invalid_cidr_fails" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "tcp", port = 80, cidr = "not-a-cidr" }]
  }
  expect_failures = [var.ingress_rules]
}

run "ingress_cidr_bad_prefix_length_fails" {
  command = plan
  variables {
    ingress_rules = [{ protocol = "tcp", port = 80, cidr = "10.0.0.0/33" }]
  }
  expect_failures = [var.ingress_rules]
}

# ── egress_rules ──────────────────────────────────────────────────────────────

run "egress_valid_rules_pass" {
  command = plan
  variables {
    egress_rules = [
      { protocol = "tcp", port = 443, cidr = "0.0.0.0/0" },
      { protocol = "udp", port = 123, cidr = "0.0.0.0/0" },
    ]
  }
}

run "egress_empty_default_passes" {
  command = plan
  variables {
    egress_rules = []
  }
}

run "egress_invalid_protocol_fails" {
  command = plan
  variables {
    egress_rules = [{ protocol = "ftp", port = 21, cidr = "0.0.0.0/0" }]
  }
  expect_failures = [var.egress_rules]
}

run "egress_invalid_cidr_fails" {
  command = plan
  variables {
    egress_rules = [{ protocol = "tcp", port = 443, cidr = "256.256.256.256/0" }]
  }
  expect_failures = [var.egress_rules]
}

run "egress_port_negative_fails" {
  command = plan
  variables {
    egress_rules = [{ protocol = "tcp", port = -1, cidr = "0.0.0.0/0" }]
  }
  expect_failures = [var.egress_rules]
}
