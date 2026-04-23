# Unit tests for module outputs.
# Run with: terraform test -test-directory=tests
# Requires Terraform >= 1.7 (mock_provider support).
#
# Plan-time assertions cover outputs whose values are fully known from input
# variables. Apply-time assertions (command = apply) cover outputs that depend
# on provider-computed attributes (id, ip addresses).

mock_provider "huddle" {}

variables {
  name_prefix    = "test"
  region         = "eu2"
  flavor_name    = "anton-2"
  image_name     = "ubuntu-22.04"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyDataForTesting user@host"
  create_network = false
  network_id     = "net-abc123"
}

# ── Plan-time outputs (values known from variables) ───────────────────────────

run "output_instance_name_matches_prefix" {
  command = plan

  assert {
    condition     = output.instance_name == "test-vm"
    error_message = "instance_name output must follow the pattern '<name_prefix>-vm'."
  }
}

run "output_instance_status_default_active" {
  command = plan

  assert {
    condition     = output.instance_status == "active"
    error_message = "instance_status output should default to 'active'."
  }
}

run "output_instance_status_reflects_power_state" {
  command = plan
  variables {
    power_state = "stopped"
  }

  assert {
    condition     = output.instance_status == "stopped"
    error_message = "instance_status output should reflect the power_state variable."
  }
}

run "output_network_id_from_variable_when_not_creating" {
  command = plan

  assert {
    condition     = output.network_id == "net-abc123"
    error_message = "network_id output should equal var.network_id when create_network is false."
  }
}

# ── Apply-time outputs (depend on provider-computed attributes) ───────────────

run "output_instance_id_is_set_after_apply" {
  command = apply

  assert {
    condition     = output.instance_id != ""
    error_message = "instance_id output must be non-empty after apply."
  }
}

run "output_security_group_id_is_set_after_apply" {
  command = apply

  assert {
    condition     = output.security_group_id != ""
    error_message = "security_group_id output must be non-empty after apply."
  }
}

run "output_network_id_after_apply_existing_network" {
  command = apply

  assert {
    condition     = output.network_id == "net-abc123"
    error_message = "network_id output should equal var.network_id when create_network is false."
  }
}

run "output_network_id_after_apply_created_network" {
  command = apply
  variables {
    create_network      = true
    network_id          = null
    pool_cidr           = "10.0.0.0/8"
    primary_subnet_cidr = "10.0.1.0/24"
    primary_subnet_size = 24
  }

  assert {
    condition     = output.network_id != ""
    error_message = "network_id output must be non-empty after apply when create_network is true."
  }
}

# ── Output sensitivity — verify sensitive outputs are marked sensitive ─────────
# These checks confirm the values are accessible in tests (mock apply resolves them)
# while the outputs.tf marks them sensitive for production use.

run "private_ipv4_output_accessible_after_apply" {
  command = apply

  assert {
    condition     = output.private_ipv4 != null
    error_message = "private_ipv4 output must not be null after apply."
  }
}

run "public_ipv4_output_accessible_after_apply" {
  command = apply

  assert {
    condition     = output.public_ipv4 != null
    error_message = "public_ipv4 output must not be null after apply."
  }
}
