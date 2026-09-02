---
name: cloud-agent-workstation
description: Use when standing up a personal always-on cloud box (AWS EC2 or any VPS) that runs a self-hosted AI agent and dev tooling, reachable from phone/laptop/tablet — "cloud dev box", "personal workstation in the cloud", "self-host an agent on a VPS", "run my agent 24/7", "work from any device". Covers Terraform baseline, sizing, native-vs-container, Tailscale access, anti-detection browsing, self-hosted search, verifying a service that logs nothing on success, and a teardown checklist that catches what `terraform destroy` misses. Do NOT use for team/production infrastructure, Kubernetes, or CI runners.
---

# Personal cloud agent workstation

A **procedure + hard-won gotchas** skill. It covers the whole arc of a personal always-on
cloud box that runs an AI agent you talk to from anywhere: provision → access → agent →
browsing/search → verify → tear down.

The recurring theme: almost none of the pain is in the Terraform. It's in provider
quirks, a healthy service that looks broken, and clients that can't reach a private
network because a VPN swallowed the route.

## When to use

- Standing up a personal dev/agent box on EC2, Hetzner, DigitalOcean, Lightsail.
- Deciding whether to run the agent natively or in a container.
- Making the box reachable from several devices without exposing ports publicly.
- Tearing one down without leaving billing or credentials behind.

Not for: multi-user or production systems, K8s, managed CI. Those want different
tradeoffs (immutability, least privilege per workload, blue/green) than a box whose whole
point is that *you* can do anything on it.

## Sizing — start small, resizing is cheap

| Workload | RAM |
|---|---|
| Agent gateway only | 2 GB |
| Agent + dev work + builds | 4 GB |
| Add a real browser (Firefox/Chromium) | 8 GB comfortable |

1 GB is below the floor for most agents — it will run, then get OOM-killed under load.
Add a swapfile early: it is free, lives on disk you already pay for, and converts a hard
kill into mere slowness. **Swap is a diagnostic, not a fix** — if it's being used heavily
rather than sitting idle as headroom, buy RAM.

Resizing is a one-line change plus a stop/start; the root volume and everything on it
survives. So do not agonise up front.

## AWS specifics that surprise people

- **The post-2025 "Free plan" restricts instance types.** Larger types fail with
  `FreeTierRestrictionError` until you upgrade to the Paid plan. Credits carry over on
  upgrade — but so does the loss of the guardrail that used to stop spending
  automatically. Set a budget alarm the same day you upgrade.
- **Every public IPv4 is billed** (since 2024). An Elastic IP therefore costs the same as
  an auto-assigned one *and* survives stop/start — always use one, or your address moves
  every resize and breaks `known_hosts` and any saved client config.
- **Official Ubuntu AMIs disable root SSH.** You land as `ubuntu` with passwordless sudo.
- **Growing the EBS volume does not grow the filesystem.** After a resize:

  ```bash
  sudo growpart /dev/nvme0n1 1 && sudo resize2fs /dev/nvme0n1p1
  ```

- AMI IDs are **region-specific** — look them up with a data source, never hardcode.

## Native vs container — decide deliberately

Running the agent **natively** lets it use the host's `git`, `gh`, `docker`, `node`, your
SSH keys and your repos. Skills that shell out just work, and there's no UID-mapping
friction with the data directory. On a workstation that is usually the right call —
a containerised agent is fenced off from the very things it's meant to work on.

The trade is real and must be stated out loud to the user: **there is no sandbox.** The
agent runs as your user with sudo. If it's also reachable over a chat platform, then
**anyone who can message it has a shell on the box**. The messaging allowlist stops being
a convenience setting and becomes the security boundary — treat it as one.

Containers still win when the agent runs untrusted work, when several agents share a host,
or when you want atomic upgrades (`docker pull` beats `git pull` + reinstall). Whichever
you pick, supervise it — systemd unit with `Restart=always`, not a process in a terminal.
For user units, `loginctl enable-linger <user>` or they die with your login session.

## Access — private network, not open ports

Put the box on a mesh VPN (Tailscale, Netbird, Nebula) and keep the cloud firewall at
SSH-only. Every device then reaches it privately with no exposed ports.

Two traps, both cost hours:

**1. A VPN/proxy client will swallow the mesh route.** If the user runs a proxy client
(xray, sing-box, Clash, and the many GUIs over them), its "direct"/bypass list usually
contains the RFC1918 ranges but **not the mesh range**. Tailnet traffic gets pushed into
the tunnel and dies there. Symptom: `curl` works but browsers and Electron apps get a
**503** — because `curl` ignores the proxy env while GUI apps obey the system proxy.

Fix in the proxy client's routing rules (durable), and/or the system proxy bypass:

```bash
# Tailscale's whole range — covers every device, now and later
gsettings set org.gnome.system.proxy ignore-hosts \
  "['localhost', '127.0.0.0/8', '::1', '100.64.0.0/10', '*.ts.net']"
export NO_PROXY="localhost,127.0.0.1,::1,100.64.0.0/10,.ts.net"
```

**2. Mesh-VPN SSH needs an ACL rule, not just a flag.** Enabling the built-in SSH server
on the host is not enough — the tailnet policy must contain an `ssh` block or the server
silently never starts (`RunSSH: true` but `RunningSSHServer: false`).

**Startup races are normal.** A desktop client launching at login often starts before the
VPN is up, fails to reach the box, and shows a connection error. Nothing is misconfigured
— retry once the VPN is connected. Do not "fix" this by disabling the VPN.

## Web UIs: bind address decides Host-header behaviour

Agent dashboards hold API keys, so they defend against DNS rebinding by validating the
`Host` header against the bound address. The rule is usually:

| Bound to | Accepts |
|---|---|
| `0.0.0.0` / `::` | any Host |
| loopback | loopback names only |
| a specific IP | **that exact Host only** |

So binding to the mesh IP *breaks SSH tunnels*, because a tunnelled browser sends
`Host: localhost`. Binding `0.0.0.0` makes both direct and tunnelled access work — and is
acceptable **only if the cloud firewall blocks that port** and auth is enabled. Verify the
firewall actually blocks it rather than assuming:

```bash
curl -m 10 http://<public-ip>:<port>/   # must time out
```

Also expect a non-loopback bind to *require* an auth provider and fail closed without one.
Modern builds make `--insecure`-style escape hatches no-ops; don't plan around them.

## Browsing and search without third-party bills

- **Plain headless Chrome gets blocked** by a lot of sites. If the user hits that, they
  need either an anti-detection browser (Camoufox-based servers run locally, free) or a
  cloud browser with residential IPs (paid). Pick based on whether they'd rather pay the
  cloud provider for RAM or pay a browser vendor.
- **Know what an "agent browser harness" actually is.** Tools marketed as state-of-the-art
  web agents are usually *drivers* — they compose with whatever browser backend you
  configure. Pointing one at local Chrome gives the same bot-detection blocks. SOTA at
  operating a page ≠ able to reach the page.
- Anti-detection browsers often **can't expose a CDP endpoint**, so you trade the fancy
  harness for the built-in tools. Say so before the user picks.
- **Self-hosted search** (SearXNG) removes the last API key. Its JSON API is off by
  default — add `json` to `search.formats` in `settings.yml` or every call 404s.
- Third-party images may not build on your arch: a `-slim` base with no C++ toolchain
  can't compile native npm modules, and files needed at runtime are sometimes never
  `COPY`'d in. Keep local patches in the repo and re-apply after upgrades.

## Verifying things that log nothing on success

**The single biggest time-waster.** Many agent gateways log at WARNING, so a *successful*
connection prints nothing and the last line reads like a hang (e.g. `Connecting… attempt
1/8`). Do not debug from silence — ask the remote service instead.

For a chat platform using long polling, exclusivity is the probe: only one client may hold
the poll, so a competing call is *rejected when things are healthy*.

```bash
# 409 Conflict  = something IS polling  → healthy
# 200 OK        = nothing is polling    → broken
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://api.<platform>/bot$TOKEN/getUpdates?timeout=0&limit=1"
```

Sample several times: a single `200` can be the gap between long polls. Generally: find
the *positive* signal (an established socket, a session record, a rejected duplicate) and
check that, rather than reading logs for absence of errors.

```bash
ss -tnp | grep ':<port>'          # is anything actually connected?
```

Two more that look like bugs and aren't:
- **"Chat not found"** on startup — a bot cannot open a conversation; the human must
  message it first.
- **Two pollers fight.** The same bot token running in two places yields endless 409s and
  messages landing unpredictably. Exactly one, always.

## Secrets hygiene

- Pull secrets from the secret manager straight to the target, then shred the local copy.
  Never echo them.
- **Filter by key name, not by line.** A multi-line value (service-account JSON, PEM) is
  not one line, so `cut -d= -f1` over a dotenv **prints the key body**. Parse with
  `python`/`jq` and print only identifiers (`client_email`, key id prefix). This mistake
  leaks a live credential into a transcript instantly.
- If a credential does leak: rotate before deleting the old one, so nothing breaks
  mid-swap; update every store that holds a copy; verify the consumer still works; only
  then delete the old key.

## Teardown — what `terraform destroy` misses

Do these **while the box is alive**, then destroy:

1. Revoke access the box was *granted*: deploy keys, machine tokens, service accounts.
2. Log it out of the mesh VPN, or you leave a dead node in the tailnet.
3. Pull anything not in version control. Enumerate it explicitly — agent boxes accumulate
   custom skills, backups and config that were never committed.

Then `terraform destroy`, and verify the three things that quietly keep billing:

```bash
aws ec2 describe-volumes   --query 'Volumes[].VolumeId'      # detached disks still bill
aws ec2 describe-addresses --query 'Addresses[].PublicIp'    # unattached EIPs bill
aws ec2 describe-snapshots --owner-ids self                  # snapshots bill
```

Finally, the orphans nothing tracks: **chat bots still exist** (their tokens stay valid —
delete via the platform's bot manager), stale local SSH keys and `known_hosts` entries,
and any client config pointing at a dead host.

Keep the Terraform repo. It becomes a blueprint: rebuilding is minutes, and the README is
where these gotchas should live for next time.
