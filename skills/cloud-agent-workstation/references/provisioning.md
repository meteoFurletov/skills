# Provisioning the software layer

Terraform gives you a bare Ubuntu box with Docker, Node, uv, swap and linger.
Everything below runs **once, over SSH**, after `terraform apply`. It is
deliberately not in `user_data`: these steps involve credentials, and
`user_data` is readable from inside the instance and stored in Terraform state.

Order matters — later steps depend on earlier ones.

```bash
ssh -i ~/.ssh/workstation ubuntu@<public_ip>
```

---

## 1. Mesh VPN (do this first)

Everything else is easier once the box has a private address.

```bash
curl -fsSL https://tailscale.com/install.sh | sudo sh
sudo tailscale up --ssh          # prints a URL — authorise in a browser
tailscale ip -4                  # note this address; used throughout
```

`--ssh` enables keyless SSH from your other devices, **but only if the tailnet
ACL policy contains an `ssh` block**. Without it the daemon reports
`RunSSH: true` while `RunningSSHServer: false`, and connections hang with no
error. Add to the policy in the admin console:

```json
"ssh": [
  { "action": "accept",
    "src": ["autogroup:member"], "dst": ["autogroup:self"],
    "users": ["autogroup:nonroot", "root"] }
]
```

Use `"check"` instead of `"accept"` to require periodic browser re-auth — more
secure, but it will hang any non-interactive/scripted SSH.

---

## 2. The agent, natively

Most self-hosted agents ship an installer that vendors the source into the data
directory and creates a venv. The generic shape:

```bash
git clone --depth 1 <agent-repo> ~/.agent/src
cd ~/.agent/src && ./setup.sh          # creates venv, installs deps, symlinks CLI
```

Then confirm the CLI resolves in a *fresh login shell* (installers commonly put
it in `~/.local/bin` and tell you to re-source your profile — verify rather
than trust):

```bash
ssh <host> 'bash -lc "command -v <agent>"'
```

Run its configuration wizard interactively. Two answers matter more than the
rest:

- **Terminal/execution backend → `local`.** Choosing a container backend here
  re-fences the agent away from the host tools you installed it natively to
  reach, defeating the whole design.
- **Messaging platform + allowlist.** Configure the allowlist immediately; most
  gateways default to denying everyone, and an empty allowlist with an open
  policy is the worst outcome.

Install it as a supervised service so it survives reboots and crashes — many
agents provide `<agent> gateway install` which writes a `systemd --user` unit.
If not, write one; `loginctl enable-linger` is already set by cloud-init.

**Model fallbacks.** If the agent supports a fallback chain, add a second
provider on a *different account*: the point is an independent quota, so
exhausting the primary doesn't stop work. Fallbacks typically trigger only on
rate-limit / 5xx / connection errors — not on a bad or refused answer.

---

## 3. Anti-detection browsing

Plain headless Chrome is blocked by a large fraction of sites. If the user
needs real browsing, the free option is a Camoufox-based server (a Firefox fork
with C++-level fingerprint spoofing) running as a local sidecar container.

```bash
git clone --depth 1 <camofox-repo> ~/camofox && cd ~/camofox
make up                                  # builds the image, starts the container
curl -s localhost:9377/health            # expect browserConnected: true
```

Two upstream packaging bugs are likely to bite; both are one-line Dockerfile
patches, and both must be re-applied after any `git pull`:

**a. Native module won't compile.** A `node:*-slim` base has `python3-minimal`
but no C++ toolchain, so `npm ci` fails building native deps (`better-sqlite3`
et al) with an opaque `gyp ERR! not ok`. Install the toolchain for the build,
then drop it:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential python3 \
    && npm ci --omit=dev \
    && apt-get purge -y build-essential && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
```

**b. Cookie persistence plugin fails to load.** `lib/cookies.js` imports
`../mcp/lib/cookies.mjs`, but `mcp/` is never `COPY`'d into the image — so
every session gets a throwaway identity and no logins survive. Add:

```dockerfile
COPY mcp/ ./mcp/
```

Then run it with a persistent profile volume (the default `make up` does not
mount one) and enable persistence in the agent's config:

```bash
docker run -d --name camofox --restart unless-stopped --shm-size=2g \
  -p 9377:9377 -v ~/.camofox:/root/.camofox <image>
```

```yaml
# nesting matters — a top-level managed_persistence is silently ignored
browser:
  camofox:
    managed_persistence: true
```

Point the agent at it (`CAMOFOX_URL=http://localhost:9377`) and restart the
gateway. Confirm the server's own request log shows the agent creating tabs —
that is the proof it routed there rather than falling back to a local browser.

**Trade-off to state up front:** anti-detection browsers usually expose no CDP
endpoint, so the fancier "web agent harness" tools cannot attach and the agent
falls back to its built-in browser tools.

---

## 4. Self-hosted search

Removes the last third-party API key.

```bash
docker run -d --name searxng --restart unless-stopped \
  -p 127.0.0.1:8888:8080 -v ~/searxng:/etc/searxng \
  searxng/searxng:latest
```

The JSON API is **off by default** — without this every agent call fails:

```yaml
# ~/searxng/settings.yml
search:
  formats:
    - html
    - json
```

```bash
docker restart searxng
curl -s 'http://localhost:8888/search?q=test&format=json' | head -c 200
```

Then set `SEARXNG_URL=http://localhost:8888` for the agent and restart it.

---

## 5. Web dashboard (for a desktop client)

Desktop apps for these agents typically connect to a *dashboard* backend, not
the agent's API server. Generate credentials **on the box** so they never pass
through a chat log or your shell history:

```bash
PW=$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)
SEC=$(openssl rand -hex 32)
printf 'DASHBOARD_BASIC_AUTH_USERNAME=%s\nDASHBOARD_BASIC_AUTH_PASSWORD=%s\nDASHBOARD_BASIC_AUTH_SECRET=%s\n' \
  "$USER" "$PW" "$SEC" >> ~/.agent/.env
chmod 600 ~/.agent/.env
# retrieve it later with: grep PASSWORD ~/.agent/.env
```

Supervise it, binding `0.0.0.0` — see `troubleshooting.md` for why that beats
binding the mesh IP, and why it is safe here:

```ini
# ~/.config/systemd/user/agent-dashboard.service
[Unit]
Description=Agent web dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/bin/<agent> dashboard --no-open --host 0.0.0.0 --port 9119
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload && systemctl --user enable --now agent-dashboard
```

Point the desktop client's "remote gateway" setting at
`http://<tailnet-ip>:9119`. Verify from another device that the public
interface is **not** reachable:

```bash
curl -m 10 http://<public-ip>:9119/    # must time out
```

---

## 6. Operating notes

**Growing the disk** after raising `root_volume_size` — Terraform resizes the
volume, but the guest filesystem does not follow:

```bash
lsblk                                        # confirm device name first
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

**Private repo access.** Use a read-only deploy key per box, not a personal
token — it is scoped to one repo and revocable independently. Record that you
created it; it is the first thing to revoke at teardown.

**Everything above is manual.** If you expect to rebuild often, fold steps 2–5
into a provisioning script and commit it next to the Terraform. Otherwise
accept that the infra is reproducible and the software layer is a checklist —
just be honest in the README about which is which.
