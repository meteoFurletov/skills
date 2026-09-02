# Troubleshooting

Symptom-first. Each entry states the *tell* that distinguishes it, because
several of these look identical from the outside.

---

## "The service is hung" — it probably isn't

**Symptom.** The last log line reads like a stalled operation
(`Connecting… attempt 1/8`) and never advances. Minutes pass. Nothing errors.

**Cause.** Many agent gateways log at WARNING. A *successful* connection prints
nothing, so healthy and hung are visually identical. Retry ladders print their
first attempt at WARNING and their success at INFO, which you never see.

**Do not debug from silence.** Find a positive signal instead:

```bash
ss -tnp | grep ':<port>'            # is anything actually connected?
ls -t ~/.agent/sessions/            # did a session record appear?
```

**For a chat platform using long polling**, exclusivity is the probe: only one
client may hold the poll, so a competing request is *rejected when healthy*.

```bash
# 409 Conflict = something IS polling → healthy
# 200 OK       = nothing is polling   → actually broken
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://api.<platform>/bot$TOKEN/getUpdates?timeout=0&limit=1"
```

Sample 3–5 times a few seconds apart: a single `200` can be the gap between
long polls. This inversion — *rejection means healthy* — is worth internalising.

**Corollary:** don't conclude a service is fine because a `docker logs` tail
shows no errors, and don't conclude it is broken because the tail looks stuck.

---

## `Chat not found` on startup

Not a bug. A bot cannot open a conversation with a human — the human must
message it first. Send `/start`, restart the gateway.

---

## Messages arrive unpredictably, endless `409 Conflict` in logs

Two processes are polling the same bot token (commonly: the old host you
migrated *from* is still running). Exactly one may poll. Stop the other, or
issue a second token for the second instance.

---

## Browser or desktop app gets 503, but `curl` works

**The tell:** `curl` succeeds while GUI apps fail. That asymmetry is the whole
diagnosis — `curl` ignores the system proxy; browsers and Electron apps obey it.

**Cause.** A VPN/proxy client (xray, sing-box, Clash and the GUIs over them)
sets a system-wide HTTP proxy. Its "direct"/bypass list contains the RFC1918
ranges but **not the mesh-VPN range**, so requests to a tailnet address are
handed to the proxy, which cannot route them and returns 503.

**Fix — in the proxy client (durable):** add the mesh range to its direct/bypass
rules. For Tailscale that is `100.64.0.0/10`. Note some clients ship routing
*disabled* by default (`useRouting=false`), in which case adding the rule
changes nothing until routing is switched on.

**Fix — system proxy (immediate, may be overwritten by the client):**

```bash
gsettings set org.gnome.system.proxy ignore-hosts \
  "['localhost', '127.0.0.0/8', '::1', '100.64.0.0/10', '*.ts.net']"
export NO_PROXY="localhost,127.0.0.1,::1,100.64.0.0/10,.ts.net"
```

Do **not** "fix" this by disabling the VPN. It works because the network was
ready by the time you retried, not because the toggle mattered.

---

## `Invalid Host header` through an SSH tunnel

**Cause.** Dashboards hold API keys, so they validate the `Host` header against
the bound address (DNS-rebinding defence). Typical rule:

| Bound to | Accepts |
|---|---|
| `0.0.0.0` / `::` | any Host |
| loopback | loopback names only |
| a specific IP | **that exact Host only** |

Binding the mesh IP therefore breaks tunnels, because a tunnelled browser sends
`Host: localhost`.

**Fix.** Bind `0.0.0.0` so direct *and* tunnelled access work — acceptable only
when the cloud firewall blocks the port and auth is enabled. Verify, don't
assume:

```bash
curl -m 10 http://<public-ip>:<port>/   # must time out
```

Expect a non-loopback bind to *require* an auth provider and fail closed
without one; modern builds have turned `--insecure`-style flags into no-ops.

---

## Desktop client fails to connect at login, works if you open settings

A startup race, not a misconfiguration: the client launches before the VPN
finishes coming up, cannot reach the box, and falls back with an error. Opening
the connection settings triggers a reconnect once the network is ready.

**The tell:** the settings pane reports "Connected" while the startup dialog
said it failed. Just retry after the VPN is up, or start the client later.

---

## `FreeTierRestrictionError` on instance resize

The AWS account is on the post-2025 **Free plan**, which restricts instance
types. Upgrade to the Paid plan (Billing → plans); unused credits carry over.

Set a budget alarm the same day — the Free plan was acting as a hard spending
guardrail, and the Paid plan has none.

---

## Disk is full after growing the volume

Terraform resized the EBS volume; the guest filesystem did not follow.

```bash
lsblk                                  # volume shows new size, partition doesn't
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

---

## Container build fails on `npm ci` with `gyp ERR! not ok`

A `-slim` Node base has no C++ toolchain, so native modules cannot compile.
Install `build-essential python3` for the build step and purge afterwards. See
`provisioning.md` §3.

---

## Agent "can't find" files that exist / permission denied

If the agent runs in a container with a bind-mounted data directory, files are
owned by the container's internal UID (often 10000) and unreadable to your
login user. That is expected and not a bug — but it is a strong argument for
running the agent natively on a single-user workstation.

---

## Leaked a credential into a log or transcript

Most likely cause: filtering a dotenv **by line** when a value is multi-line.
`cut -d= -f1` over a file containing a service-account JSON or PEM prints the
key body, because those are not one line.

Parse with `python`/`jq` and print only identifiers (`client_email`, an id
prefix). Then rotate, in this order:

1. Create the new key **before** deleting the old one, so nothing breaks mid-swap.
2. Update every store holding a copy (secret manager, CI secrets, each host).
3. Verify the consumer still works.
4. Only then delete the old key.

A credential that is unused *here* is not retired — it stays valid wherever it
is still deployed.
