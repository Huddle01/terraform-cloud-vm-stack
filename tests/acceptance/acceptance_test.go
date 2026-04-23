// Acceptance tests for the vm-stack Terraform module.
//
// These tests provision real infrastructure against the Huddle01 Cloud API and
// are therefore gated behind environment variables. They are skipped
// automatically when those variables are absent, so they never run in the
// unit-test job.
//
// Required environment variables:
//
//	HUDDLE_API_KEY     — Huddle01 API key with compute/network permissions
//	HUDDLE_REGION      — Target region (e.g. "eu2")
//	HUDDLE_FLAVOR_NAME — VM flavor name to use (e.g. "anton-2")
//	HUDDLE_IMAGE_NAME  — OS image to boot from (e.g. "ubuntu-22.04")
//
// Optional environment variables:
//
//	HUDDLE_LOCAL_BASE_URL      — API endpoint to target (default: production).
//	                             Set to e.g. http://localhost:8080/api/v1 to
//	                             test against a local API server. Passed to the
//	                             fixture as the provider base_url argument.
//	HUDDLE_EXISTING_NETWORK_ID — network ID to use in TestExistingNetwork;
//	                             the test is skipped if not set.
//	TF_SKIP_INIT=1             — skip `terraform init` (use when the provider
//	                             is resolved via dev_overrides).
//
// Run with:
//
//	go test -v -timeout 30m ./...
//
// Or via the module Makefile:
//
//	make test-acceptance          # against production
//	make test-acceptance-dev      # with dev_overrides
//	make test-acceptance-local    # against a local API server

package acceptance_test

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const fixtureDir = "./fixtures"

// envOrSkip returns the value of an environment variable, or skips the test if
// any of the provided variables are unset.
func envOrSkip(t *testing.T, names ...string) map[string]string {
	t.Helper()
	out := make(map[string]string, len(names))
	for _, n := range names {
		v := os.Getenv(n)
		if v == "" {
			t.Skipf("skipping acceptance test: environment variable %s is not set", n)
		}
		out[n] = v
	}
	return out
}

func requiredVars(t *testing.T) (apiKey, region, flavorName, imageName string) {
	t.Helper()
	env := envOrSkip(t, "HUDDLE_API_KEY", "HUDDLE_REGION", "HUDDLE_FLAVOR_NAME", "HUDDLE_IMAGE_NAME")
	return env["HUDDLE_API_KEY"], env["HUDDLE_REGION"], env["HUDDLE_FLAVOR_NAME"], env["HUDDLE_IMAGE_NAME"]
}

// applyBaseURL injects the base_url Terraform variable when HUDDLE_LOCAL_BASE_URL
// is set in the environment. The entry is omitted entirely when the variable is
// absent so the fixture falls back to its null default and the provider uses its
// built-in production endpoint.
func applyBaseURL(vars map[string]interface{}) map[string]interface{} {
	if u := os.Getenv("HUDDLE_LOCAL_BASE_URL"); u != "" {
		// Make's -include preserves literal quote characters from .env files.
		// Strip them so the URL is valid for url.Parse inside the provider.
		u = strings.Trim(u, `"'`)
		vars["base_url"] = u
	}
	return vars
}

// TestFullStack provisions a complete vm-stack (new network + public IP) and
// verifies all outputs are populated and the instance is reachable over SSH.
func TestFullStack(t *testing.T) {
	t.Parallel()
	apiKey, region, flavorName, imageName := requiredVars(t)
	kp := generateSSHKeyPair(t)

	opts := &terraform.Options{
		TerraformDir: copyFixtures(t, fixtureDir),
		Vars: applyBaseURL(map[string]interface{}{
			"api_key":             apiKey,
			"region":              region,
			"flavor_name":         flavorName,
			"image_name":            imageName,
			"ssh_public_key":      kp.PublicKey,
			"name_prefix":         uniquePrefix("acc-full"),
			"pool_cidr":           "10.10.0.0/16",
			"primary_subnet_cidr": "10.10.1.0/24",
			"primary_subnet_size": 24,
			"ingress_rules": []map[string]interface{}{
				{"protocol": "tcp", "port": 22, "cidr": "0.0.0.0/0"},
			},
		}),
		NoColor: true,
	}

	defer terraform.Destroy(t, opts)
	applyFixture(t, opts)

	// Outputs must all be populated.
	instanceID   := terraform.Output(t, opts, "instance_id")
	instanceName := terraform.Output(t, opts, "instance_name")
	networkID    := terraform.Output(t, opts, "network_id")
	sgID         := terraform.Output(t, opts, "security_group_id")
	publicIP     := terraform.Output(t, opts, "public_ipv4")
	privateIP    := terraform.Output(t, opts, "private_ipv4")

	require.NotEmpty(t, instanceID,   "instance_id must not be empty")
	require.NotEmpty(t, instanceName, "instance_name must not be empty")
	require.NotEmpty(t, networkID,    "network_id must not be empty")
	require.NotEmpty(t, sgID,         "security_group_id must not be empty")
	require.NotEmpty(t, publicIP,     "public_ipv4 must not be empty when assign_public_ip is true")
	require.NotEmpty(t, privateIP,    "private_ipv4 must not be empty")

	assert.Equal(t, "active", terraform.Output(t, opts, "instance_status"),
		"instance_status should be 'active' after apply")

	// Verify the injected SSH key grants access.
	assertSSHConnectivity(t, publicIP, kp)
}

// TestExistingNetwork verifies that the module can attach to a pre-existing
// network instead of creating one.
func TestExistingNetwork(t *testing.T) {
	t.Parallel()
	apiKey, region, flavorName, imageName := requiredVars(t)

	existingNetworkID := os.Getenv("HUDDLE_EXISTING_NETWORK_ID")
	if existingNetworkID == "" {
		t.Skip("skipping: HUDDLE_EXISTING_NETWORK_ID is not set")
	}

	kp := generateSSHKeyPair(t)

	opts := &terraform.Options{
		TerraformDir: copyFixtures(t, fixtureDir),
		Vars: applyBaseURL(map[string]interface{}{
			"api_key":        apiKey,
			"region":         region,
			"flavor_name":    flavorName,
			"image_name":       imageName,
			"ssh_public_key": kp.PublicKey,
			"name_prefix":    uniquePrefix("acc-extnet"),
			"create_network": false,
			"network_id":     existingNetworkID,
		}),
		NoColor: true,
	}

	defer terraform.Destroy(t, opts)
	applyFixture(t, opts)

	networkID := terraform.Output(t, opts, "network_id")
	assert.Equal(t, existingNetworkID, networkID,
		"network_id output should match the provided existing network ID")

	require.NotEmpty(t, terraform.Output(t, opts, "instance_id"),
		"instance_id must be populated")
}

// TestNoPublicIP verifies that public_ipv4 is empty when assign_public_ip = false.
func TestNoPublicIP(t *testing.T) {
	t.Parallel()
	apiKey, region, flavorName, imageName := requiredVars(t)
	kp := generateSSHKeyPair(t)

	opts := &terraform.Options{
		TerraformDir: copyFixtures(t, fixtureDir),
		Vars: applyBaseURL(map[string]interface{}{
			"api_key":             apiKey,
			"region":              region,
			"flavor_name":         flavorName,
			"image_name":            imageName,
			"ssh_public_key":      kp.PublicKey,
			"name_prefix":         uniquePrefix("acc-nopip"),
			"assign_public_ip":    false,
			"pool_cidr":           "10.20.0.0/16",
			"primary_subnet_cidr": "10.20.1.0/24",
			"primary_subnet_size": 24,
		}),
		NoColor: true,
	}

	defer terraform.Destroy(t, opts)
	applyFixture(t, opts)

	publicIP := terraform.Output(t, opts, "public_ipv4")
	assert.Empty(t, publicIP, "public_ipv4 must be empty when assign_public_ip is false")

	privateIP := terraform.Output(t, opts, "private_ipv4")
	assert.NotEmpty(t, privateIP, "private_ipv4 must still be populated")
}

// TestStoppedPowerState verifies that power_state = "stopped" is reflected in outputs.
func TestStoppedPowerState(t *testing.T) {
	t.Parallel()
	apiKey, region, flavorName, imageName := requiredVars(t)
	kp := generateSSHKeyPair(t)

	opts := &terraform.Options{
		TerraformDir: copyFixtures(t, fixtureDir),
		Vars: applyBaseURL(map[string]interface{}{
			"api_key":             apiKey,
			"region":              region,
			"flavor_name":         flavorName,
			"image_name":            imageName,
			"ssh_public_key":      kp.PublicKey,
			"name_prefix":         uniquePrefix("acc-stop"),
			"power_state":         "stopped",
			"pool_cidr":           "10.30.0.0/16",
			"primary_subnet_cidr": "10.30.1.0/24",
			"primary_subnet_size": 24,
		}),
		NoColor: true,
	}

	defer terraform.Destroy(t, opts)
	applyFixture(t, opts)

	status := terraform.Output(t, opts, "instance_status")
	assert.Equal(t, "stopped", status,
		"instance_status must be 'stopped' when power_state is set to stopped")
}

// TestRestrictedEgress verifies that explicit egress rules are applied without
// disrupting the instance creation flow.
func TestRestrictedEgress(t *testing.T) {
	t.Parallel()
	apiKey, region, flavorName, imageName := requiredVars(t)
	kp := generateSSHKeyPair(t)

	opts := &terraform.Options{
		TerraformDir: copyFixtures(t, fixtureDir),
		Vars: applyBaseURL(map[string]interface{}{
			"api_key":             apiKey,
			"region":              region,
			"flavor_name":         flavorName,
			"image_name":            imageName,
			"ssh_public_key":      kp.PublicKey,
			"name_prefix":         uniquePrefix("acc-egress"),
			"pool_cidr":           "10.40.0.0/16",
			"primary_subnet_cidr": "10.40.1.0/24",
			"primary_subnet_size": 24,
			"egress_rules": []map[string]interface{}{
				{"protocol": "tcp", "port": 443, "cidr": "0.0.0.0/0"},
			},
		}),
		NoColor: true,
	}

	defer terraform.Destroy(t, opts)
	applyFixture(t, opts)

	require.NotEmpty(t, terraform.Output(t, opts, "instance_id"),
		"instance should be created successfully even with explicit egress rules")
	require.NotEmpty(t, terraform.Output(t, opts, "security_group_id"),
		"security_group_id must be populated")
}

// TestIdempotent verifies that applying the same configuration twice results
// in zero planned changes (Terraform idempotency).
func TestIdempotent(t *testing.T) {
	t.Parallel()
	apiKey, region, flavorName, imageName := requiredVars(t)
	kp := generateSSHKeyPair(t)

	opts := &terraform.Options{
		TerraformDir: copyFixtures(t, fixtureDir),
		Vars: applyBaseURL(map[string]interface{}{
			"api_key":             apiKey,
			"region":              region,
			"flavor_name":         flavorName,
			"image_name":            imageName,
			"ssh_public_key":      kp.PublicKey,
			"name_prefix":         uniquePrefix("acc-idem"),
			"pool_cidr":           "10.50.0.0/16",
			"primary_subnet_cidr": "10.50.1.0/24",
			"primary_subnet_size": 24,
			"ingress_rules": []map[string]interface{}{
				{"protocol": "tcp", "port": 443, "cidr": "0.0.0.0/0"},
			},
		}),
		NoColor: true,
	}

	defer terraform.Destroy(t, opts)
	applyFixture(t, opts)

	// Second apply must produce no changes.
	exitCode := terraform.PlanExitCode(t, opts)
	assert.Equal(t, 0, exitCode,
		"second plan should produce no changes (exit code 0); got exit code %d", exitCode)
}
