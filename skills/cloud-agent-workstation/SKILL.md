---
name: cloud-agent-workstation
description: Use when standing up, operating or tearing down a personal always-on cloud box (AWS EC2 or any VPS) that runs a self-hosted AI agent plus dev tooling, reachable from phone/laptop/tablet — "cloud dev box", "personal workstation in the cloud", "self-host an agent on a VPS", "run my agent 24/7", "work from any device", "rebuild my cloud box". Ships runnable Terraform, a provisioning runbook (mesh VPN, native agent install, anti-detection browsing, self-hosted search, dashboard), symptom-first troubleshooting, and a teardown checklist that catches what `terraform destroy` misses. Do NOT use for team/production infrastructure, Kubernetes, or CI runners.
---

# Personal cloud agent workstation

A **procedure** skill with working code. It covers the whole arc: provision →
access → agent → browsing/search → verify → tear down. Everything needed to
rebuild from scratch is in this directory.

```
terraform/       runnable — EC2 + EIP + security group + cloud-init
references/
  provisioning.md    the software layer, in order, with commands
  troubleshooting.md symptom-first; read before debugging anything
  teardown.md        what terraform destroy does not remove
```

The recurring lesson: **almost none of the difficulty is in the Terraform.** It
is in provider quirks, a healthy service that looks broken, and clients that
can't reach a private network because a VPN swallowed the route. Budget your
attention accordingly.

## When to use

- Standing up a personal dev/agent box on EC2, Hetzner, DigitalOcean, Lightsail.
- Deciding native vs container for the agent.
- Reaching it from several devices without exposing ports.
- Tearing one down without leaving billing or credentials behind.

Not for multi-user or production systems, Kubernetes, or managed CI — those
want immutability and least-privilege-per-workload, the opposite of a box whose
entire purpose is that *you* can do anything on it.

## Quick start

```bash
cp -r <this-skill>/terraform ~/Projects/<name>/terraform
cd ~/Projects/<name>/terraform
ssh-keygen -t ed25519 -f ~/.ssh/workstation
cp terraform.tfvars.example terraform.tfvars   # paste the .pub contents
terraform init && terraform apply
```

Then work through `references/provisioning.md` in order. Expect ~30 minutes;
the interactive agent wizard and the VPN authorisation cannot be automated.

## The decisions that actually matter

### Sizing — start small, resizing is cheap

| Workload | RAM |
|---|---|
| Agent gateway only | 2 GB |
| Agent + dev work + builds | 4 GB |
| Plus a real browser (Firefox/Chromium) | 8 GB comfortable |

1 GB is below the floor — it boots, then gets OOM-killed under load. A swapfile
(cloud-init creates one) turns a hard kill into slowness, but **heavy swap use
means buy RAM**; it is headroom, not a fix. Resizing is one line plus a
stop/start and the disk survives, so don't agonise up front.

### Native vs container — decide deliberately, say the consequence out loud

Running the agent **natively** lets it use the host's `git`, `gh`, `docker`,
`node`, your SSH keys and your repos. Skills that shell out just work, with no
UID-mapping friction on the data directory. On a single-user workstation that
is usually right: a containerised agent is fenced off from the very things it
exists to work on.

The trade is real and must be stated to the user rather than buried:
**there is no sandbox.** The agent runs as your user with sudo. If it is also
reachable over a chat platform, **anyone who can message it has a shell on the
box** — the messaging allowlist stops being a convenience setting and becomes
the security boundary.

Containers still win for untrusted work, multiple agents per host, or atomic
upgrades (`docker pull` beats `git pull` + reinstall). Either way: supervise it
with systemd and `Restart=always`, and `loginctl enable-linger` for user units.

### Access — private network, not open ports

Mesh VPN (Tailscale et al) with the cloud firewall at SSH-only. Every device
reaches the box privately; nothing is exposed. Two traps that each cost hours
are documented in `troubleshooting.md`: a proxy client swallowing the mesh
route (the tell: `curl` works, browsers 503), and mesh-VPN SSH silently not
starting without an ACL `ssh` block.

### Browsing and search without third-party bills

- Plain headless Chrome is blocked by many sites. Free fix: a Camoufox-based
  anti-detection server as a local sidecar. Paid fix: a cloud browser with
  residential IPs. Choose by whether the user would rather pay the cloud
  provider for RAM or a browser vendor for stealth.
- **A "SOTA web agent harness" is a driver, not a browser.** It composes with
  whatever backend you configure — point it at local Chrome and you get the
  same blocks. Good at *operating* a page ≠ able to *reach* it. Anti-detection
  browsers usually expose no CDP endpoint, so you trade the harness for the
  built-in tools; say so before the user picks.
- Self-hosted search (SearXNG) removes the last API key. Its JSON API is off by
  default — enable it or every call fails.

## Verifying things that log nothing on success

The single biggest time-waster, so it gets its own rule:

> **Find the positive signal. Never infer health from the absence of errors.**

Many agent gateways log at WARNING, so success prints nothing and the last line
looks like a hang. Check an established socket, a session record, or — for a
chat platform using long polling — the fact that a competing request gets
**rejected**:

```bash
# 409 Conflict = something IS polling → healthy;  200 = nothing polling → broken
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://api.<platform>/bot$TOKEN/getUpdates?timeout=0&limit=1"
```

Sample several times — one `200` can be the gap between long polls.

## Secrets hygiene

- Pull secrets from the secret manager straight to the target; shred the local
  copy; never echo them.
- **Filter by key name, not by line.** A multi-line value (service-account
  JSON, PEM) is not one line, so `cut -d= -f1` over a dotenv **prints the key
  body**. Parse with `python`/`jq` and print only identifiers. This is how a
  live credential ends up in a transcript.
- Rotating: create the new key *before* deleting the old, update every store
  that holds a copy, verify the consumer, then delete. A credential unused
  *here* is not retired — it stays valid wherever it is still deployed.

## Cost

`t3.medium` + 50 GB gp3 + one Elastic IP ≈ **$43/month** in `eu-central-1`.
Roughly: instance ~$35, public IPv4 ~$3.65 (billed since 2024, EIP or not),
disk ~$4. Stopping the instance when idle drops the compute portion but keeps
charging for disk and any *unattached* EIP.

See `references/teardown.md` before deleting anything — three resource types
keep billing after an instance is terminated.
