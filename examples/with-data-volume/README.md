# Example: with-data-volume

Provisions a VM stack together with a standalone data volume, following the recommended explicit volume lifecycle:

1. Create the VM via the `vm_stack` module.
2. Create a standalone `huddle_cloud_volume`.
3. Attach it with `huddle_cloud_volume_attachment`.
4. Detach by removing the attachment resource.
5. Delete the volume only after it is detached.

This keeps storage lifecycle independent from compute lifecycle — the volume survives `terraform destroy` by default (`delete_on_destroy = false`), so data is preserved when the VM is torn down.

## Required variables

- `huddle_api_key`
- `flavor_name` — e.g. `anton-2`
- `image_name` — e.g. `ubuntu-22.04`
- `ssh_public_key`

Optional:
- `volume_size` (default: `100` GB)

## Apply

```bash
terraform init
terraform apply \
  -var="huddle_api_key=<key>" \
  -var="flavor_name=anton-2" \
  -var="image_name=ubuntu-22.04" \
  -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)"
```

## Volume retention on destroy

By default the volume is **not** deleted when `terraform destroy` is run — only the attachment and VM are removed.
To permanently delete the volume on destroy, set:

```hcl
resource "huddle_cloud_volume" "data" {
  ...
  delete_on_destroy = true
}
```

> **Warning:** `delete_on_destroy = true` permanently destroys all data on the volume and cannot be undone.
