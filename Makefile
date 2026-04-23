.PHONY: fmt validate test-unit test-acceptance test acc-deps

# Load credentials from .env.acceptance when it exists (file is gitignored).
# Copy .env.acceptance.example → .env.acceptance and fill in your values.
# Any variable already exported in the shell takes precedence over the file.
ENV_FILE ?= .env.acceptance
-include $(ENV_FILE)
export

# ── Formatting & validation ───────────────────────────────────────────────────

fmt:
	terraform fmt -recursive .

validate:
	terraform init -backend=false
	terraform validate

# ── Unit tests (no credentials required) ─────────────────────────────────────
# Uses the native `terraform test` framework with mock_provider blocks.
# Requires Terraform >= 1.7.

test-unit:
	terraform test -test-directory=tests

# ── Acceptance tests (requires live API credentials) ─────────────────────────
# Provisions real infrastructure. Credentials are loaded from .env.acceptance
# automatically (see top of file). The following variables are recognised:
#
#   HUDDLE_API_KEY              required
#   HUDDLE_REGION               required  (e.g. eu2)
#   HUDDLE_FLAVOR_NAME          required  (e.g. anton-2)
#   HUDDLE_IMAGE_NAME           required  (e.g. ubuntu-22.04)
#   HUDDLE_EXISTING_NETWORK_ID  optional  — enables TestExistingNetwork
#
#   HUDDLE_LOCAL_BASE_URL       optional  — override the API endpoint.
#                               Use this to point tests at a local API server
#                               (e.g. http://localhost:8080/api/v1) instead of
#                               production. Passed to the fixture as the
#                               provider base_url argument.
#
#   TF_SKIP_INIT=1              set this when using provider dev_overrides
#                               (e.g. `make dev-override` in the provider/
#                               directory). Terraform itself warns against
#                               running `init` with dev_overrides in effect.
#
# -count=1 is always passed to disable Go's test result cache. Acceptance tests
# provision real infrastructure whose state can change between runs, so cached
# results are never meaningful here.
#
# Default local API endpoint used by the `*-local` convenience targets.
HUDDLE_LOCAL_BASE_URL ?= http://localhost:8080/api/v1

test-acceptance:
	cd tests/acceptance && go test -v -count=1 -timeout 30m ./...

# Convenience target for local dev when provider dev_overrides is configured
# (skips terraform init) but still points at production or whatever
# HUDDLE_LOCAL_BASE_URL is set to.
test-acceptance-dev:
	cd tests/acceptance && TF_SKIP_INIT=1 go test -v -count=1 -timeout 30m ./...

# Convenience target: runs acceptance tests against a local API server.
# Start the API first: `cd api && make dev`
# Override the URL with: make test-acceptance-local HUDDLE_LOCAL_BASE_URL=http://localhost:9090/api/v1
test-acceptance-local:
	cd tests/acceptance && \
	  TF_SKIP_INIT=1 \
	  go test -v -count=1 -timeout 30m ./...

# ── Run both ──────────────────────────────────────────────────────────────────

test: test-unit test-acceptance

# ── Install Go dependencies for acceptance tests ──────────────────────────────

acc-deps:
	cd tests/acceptance && go mod tidy
