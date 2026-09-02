# Teardown

`terraform destroy` removes what Terraform created. It does **not** remove
access you granted the box elsewhere, nor identities it registered, nor
anything that lives only on its disk. Work top to bottom.

## 1. While the box is still alive

**Enumerate what is not in version control — explicitly, don't assume.** Agent
boxes accumulate custom skills, backups, cron jobs and config that were never
committed. Ask the owner to confirm *after* showing them the list, not before:

```bash
ls -lh ~/*.tgz ~/*.tar.gz 2>/dev/null      # ad-hoc backups
du -sh ~/.agent                            # how much state is there
<agent> skills list | grep -i local        # locally authored skills
<agent> cron list                          # scheduled jobs
for d in ~/*/ /opt/*/; do
  [ -d "$d/.git" ] && { echo "-- $d"; git -C "$d" status --short; }
done                                       # uncommitted / unpushed work
```

**Revoke what the box was granted.** These outlive the instance:

```bash
gh repo deploy-key list --repo <owner>/<repo>
gh repo deploy-key delete <id> --repo <owner>/<repo>
```

Also: cloud service-account keys, CI tokens, secret-manager machine identities,
anything issued *for* this host.

**Leave the mesh VPN**, or a dead node lingers in the tailnet:

```bash
sudo tailscale logout
```

## 2. Destroy

```bash
terraform plan -destroy    # confirm the count matches what you expect
terraform destroy
```

## 3. Verify nothing still bills

Terminating an instance does not necessarily remove its storage, and these are
the three that quietly keep charging:

```bash
aws ec2 describe-volumes   --query 'Volumes[].VolumeId'     # detached disks bill
aws ec2 describe-addresses --query 'Addresses[].PublicIp'   # unattached EIPs bill
aws ec2 describe-snapshots --owner-ids self                 # snapshots bill
```

All three empty ⇒ spend is zero. (`delete_on_termination = true` on the root
volume is what makes the first one empty; confirm rather than trust it.)

Check other regions too if you ever experimented outside your default one —
resources are regional and easy to forget.

## 4. Orphans nothing tracks

- **Chat bots still exist.** Their tokens remain valid; the box being gone
  changes nothing. Delete via the platform's bot manager if unwanted.
- **Stale SSH keys and `known_hosts` entries** on every machine you connected
  from:

  ```bash
  rm -f ~/.ssh/<name> ~/.ssh/<name>.pub
  ssh-keygen -R <old-ip>
  ```

- **Client configs** pointing at the dead host (desktop apps, tunnels, VPN
  routing rules). Mesh-range proxy bypasses are worth *keeping* — they apply to
  any future tailnet device.

## 5. Keep the Terraform repo

It is now a blueprint: `terraform apply` rebuilds the machine in minutes. Note
in its README which parts are reproducible (the infra) and which are a manual
checklist (the software layer) — that distinction is exactly what a future
rebuild needs to know, and exactly what gets forgotten.
