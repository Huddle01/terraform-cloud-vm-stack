package acceptance_test

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/ssh"
)

// applyFixture runs terraform apply for the given options. If TF_SKIP_INIT=1 is
// set (e.g. when using provider dev_overrides), init is skipped because
// Terraform itself warns against running init with dev_overrides. Otherwise
// the standard InitAndApply flow is used.
//
// Before applying, it injects HUDDLE_BASE_URL (if set) into opts.Vars as
// `base_url`. Passing it through a Terraform variable is more reliable than
// relying on env-var inheritance from Terratest → terraform CLI → provider
// plugin, and it shows up in plan output for easy debugging.
func applyFixture(t *testing.T, opts *terraform.Options) {
	t.Helper()

	// Inject base_url if not already set by applyBaseURL (which reads HUDDLE_LOCAL_BASE_URL).
	// Fall back to HUDDLE_BASE_URL for environments that still use the legacy name.
	if _, set := opts.Vars["base_url"]; !set {
		baseURL := os.Getenv("HUDDLE_LOCAL_BASE_URL")
		if baseURL == "" {
			baseURL = os.Getenv("HUDDLE_BASE_URL")
		}
		if baseURL != "" {
			// Make's -include preserves literal quote characters from .env files.
			// Strip them so the URL is valid for url.Parse inside the provider.
			baseURL = strings.Trim(baseURL, `"'`)
			if opts.Vars == nil {
				opts.Vars = map[string]interface{}{}
			}
			opts.Vars["base_url"] = baseURL
			t.Logf("acceptance tests targeting API at %s", baseURL)
		}
	}

	if os.Getenv("TF_SKIP_INIT") == "1" {
		// With dev_overrides the provider is resolved from the local binary,
		// but terraform init is still required to install local modules into
		// the (fresh) per-test working directory.
		terraform.Init(t, opts)
		terraform.Apply(t, opts)
		return
	}
	terraform.InitAndApply(t, opts)
}

type sshKeyPair struct {
	PublicKey  string
	privateKey *rsa.PrivateKey
}

// generateSSHKeyPair creates an ephemeral RSA key pair for use in acceptance tests.
// The public key is in OpenSSH authorized_keys format.
func generateSSHKeyPair(t *testing.T) sshKeyPair {
	t.Helper()

	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	require.NoError(t, err, "failed to generate RSA key pair")

	pubKey, err := ssh.NewPublicKey(&priv.PublicKey)
	require.NoError(t, err, "failed to derive SSH public key")

	return sshKeyPair{
		PublicKey:  string(ssh.MarshalAuthorizedKey(pubKey)),
		privateKey: priv,
	}
}

// privateKeyPEM returns the PEM-encoded private key bytes.
func (kp sshKeyPair) privateKeyPEM() []byte {
	return pem.EncodeToMemory(&pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(kp.privateKey),
	})
}

// assertSSHConnectivity dials the instance over SSH and runs `hostname` to
// confirm the instance is reachable and the injected key is accepted.
func assertSSHConnectivity(t *testing.T, host string, kp sshKeyPair) {
	t.Helper()

	signer, err := ssh.ParsePrivateKey(kp.privateKeyPEM())
	require.NoError(t, err, "failed to parse private key")

	cfg := &ssh.ClientConfig{
		User: "ubuntu", // default user for ubuntu images
		Auth: []ssh.AuthMethod{ssh.PublicKeys(signer)},
		// Accept any host key — this is a freshly provisioned VM we control.
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), //nolint:gosec
		Timeout:         10 * time.Second,
	}

	addr := net.JoinHostPort(host, "22")

	var client *ssh.Client
	require.Eventually(t, func() bool {
		client, err = ssh.Dial("tcp", addr, cfg)
		return err == nil
	}, 3*time.Minute, 10*time.Second,
		"timed out waiting for SSH to become available at %s", addr,
	)
	defer client.Close()

	session, err := client.NewSession()
	require.NoError(t, err, "failed to open SSH session")
	defer session.Close()

	out, err := session.Output("hostname")
	require.NoError(t, err, "failed to run hostname over SSH")
	t.Logf("SSH connectivity verified — hostname: %s", string(out))
}

// uniquePrefix generates a short unique name prefix for test resources to
// avoid collisions when multiple acceptance runs execute concurrently.
func uniquePrefix(base string) string {
	return fmt.Sprintf("%s-%d", base, time.Now().UnixMilli()%100000)
}

// copyFixtures copies the fixtures directory into a per-test temp directory so
// that parallel tests each get an isolated Terraform working directory (and
// therefore an isolated terraform.tfstate). Without this, parallel tests share
// state and race on the same OpenStack resources.
//
// main.tf contains `source = "../../../"` which is relative to the original
// fixtures location. After copying to a temp dir the relative path would be
// wrong, so we rewrite it to the absolute path of the module root.
func copyFixtures(t *testing.T, src string) string {
	t.Helper()

	absSrc, err := filepath.Abs(src)
	require.NoError(t, err, "resolve fixtures abs path")

	// Module root is three levels above fixtures/ (fixtures → acceptance → tests → module root).
	moduleRoot := filepath.Join(absSrc, "..", "..", "..")
	moduleRoot, err = filepath.Abs(moduleRoot)
	require.NoError(t, err, "resolve module root abs path")

	dst := t.TempDir()

	entries, err := os.ReadDir(absSrc)
	require.NoError(t, err, "read fixtures dir")

	// Files that must never be copied to a fresh temp dir.
	// - .terraform.lock.hcl: stale lock pins can conflict with the required
	//   provider version in main.tf; each test resolves the provider anew.
	// - terraform.tfstate / terraform.tfstate.backup: leftover from a previous
	//   failed run; copying them causes Terraform to refresh (and fail on)
	//   resources that no longer exist in the remote API.
	skipFiles := map[string]bool{
		".terraform.lock.hcl":      true,
		"terraform.tfstate":        true,
		"terraform.tfstate.backup": true,
	}

	for _, e := range entries {
		if e.IsDir() || skipFiles[e.Name()] {
			continue
		}
		srcPath := filepath.Join(absSrc, e.Name())
		dstPath := filepath.Join(dst, e.Name())

		data, err := os.ReadFile(srcPath)
		require.NoError(t, err, "read fixture file %s", e.Name())

		if e.Name() == "main.tf" {
			// Rewrite the relative module source to an absolute path so that
			// Terraform can find the module regardless of where the temp dir is.
			data = []byte(replaceModuleSource(string(data), filepath.ToSlash(moduleRoot)))
		}

		require.NoError(t, os.WriteFile(dstPath, data, 0o644), "write fixture %s", e.Name())
	}

	return dst
}

// replaceModuleSource rewrites `source = "../../../"` in a main.tf to use an
// absolute path, which remains valid regardless of the working directory.
func replaceModuleSource(content, absModuleRoot string) string {
	return strings.ReplaceAll(content, `source = "../../../"`, `source = "`+absModuleRoot+`"`)
}
