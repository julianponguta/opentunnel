# OpenTunnel

Connect to remote servers behind NAT/firewall using SSH over a Pinggy TCP tunnel.

Nothing to install on either end (stock `ssh` everywhere). No account, no email anywhere.

---

## OpenCode / AI Agents

Let AI agents control remote servers through SSH tunnels.

**Option A: Let an LLM do it**

Paste this into any LLM agent (Claude Code, OpenCode, Cursor, etc.):

```
Install the opentunnel-connect skill by running: npx skills add julianponguta/opentunnel/skills/opentunnel-connect
Then configure ezssh MCP in ~/.config/opencode/opencode.json with: { "mcp": { "ezssh": { "command": ["npx", "-y", "ezssh-mcp"], "enabled": true, "type": "local" } } }
```

**Option B: Manual setup**

```bash
npx skills add julianponguta/opentunnel/skills/opentunnel-connect
```

Add ezssh MCP to `~/.config/opencode/opencode.json`:
```json
{
  "mcp": {
    "ezssh": {
      "command": ["npx", "-y", "ezssh-mcp"],
      "enabled": true,
      "type": "local"
    }
  }
}
```

See [AGENT_SETUP.md](AGENT_SETUP.md) for agent workflow.

---

## Quick Start

No prerequisites. `ssh` already comes with Linux, macOS and Windows 10+.

### Install

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> ~/.bashrc && source ~/.bashrc
```

---

## Two Ways to Connect

### Option A: Password (Simplest)

Run on the remote server (Linux):
```bash
ot                    # creates tunneluser with temp password
```

Or on a Windows remote (PowerShell as Admin):
```powershell
irm https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.ps1 -OutFile $env:TEMP\ot.ps1; & $env:TEMP\ot.ps1
```

Server outputs:
```
Tunnel: abc-12-34-56.run.pinggy-free.link:33045
User: tunneluser
Password: abc123xyz789
```

Connect from your machine (plain ssh):
```bash
ssh -p 33045 tunneluser@abc-12-34-56.run.pinggy-free.link
# Enter password shown above
```

---

### Option B: SSH Key (Recommended)

The key is always sent WITHOUT comment/email. Only `ssh-ed25519 AAAA...` travels in the command, never `user@email`.

1. Get your public key (on your local machine), dropping the trailing comment:
   ```bash
   awk '{print $1" "$2}' ~/.ssh/id_ed25519.pub
   ```

2. Run on the remote server with your key:
   ```bash
   ot root "ssh-ed25519 AAAA..."
   ```

3. Server outputs:
   ```
   Tunnel: abc-12-34-56.run.pinggy-free.link:33045
   User: root
   ```

4. Connect from your machine:
   ```bash
   ssh -i ~/.ssh/id_ed25519 -p 33045 root@abc-12-34-56.run.pinggy-free.link
   ```

Tip: `opentunnel.exe` does steps 1-2 for you and sanitizes the key automatically. Use `--no-key` for password mode (nothing of your key leaves your machine).

---

## Commands

| Command | Duration | User | Auth |
|---------|----------|------|------|
| `ot` | 60 min | tunneluser | temp password |
| `ot root` | 60 min | root | existing password |
| `ot 30` | 30 min | tunneluser | temp password |
| `ot 30 root` | 30 min | root | existing password |
| `ot 60 root "ssh-ed25519 AAAA..."` | 60 min | root | SSH key (no email) |

Windows remote equivalents: `& $env:TEMP\ot.ps1 -Minutes 30 -User Administrator -SshKey "ssh-ed25519 AAAA..."`

---

## How it Works

1. **Server**: Opens a reverse TCP tunnel with `ssh -R0:localhost:22 tcp@free.pinggy.io` (no auth, port 443 out)
2. **Fallback**: if Pinggy free rejects (`Permission denied`), downloads `bore` v0.6.0 (single binary, no account) and tunnels via `bore.pub`
3. **Output**: Shows `host:port` + credentials
4. **You**: Connect with plain `ssh -p PORT user@host`

SSH traffic is end-to-end encrypted by your own `sshd`; the relay only sees ciphertext.

> Windows remote: `bore.exe` is flagged as PUA by Defender (it opens reverse
> tunnels). The script adds an exclusion for it (runs as Admin). Official
> binary `ekzhang/bore` v0.6.0, hash-verified.

---

## otd — relay without account or expiry (Portal)

`cmd/otd` is the remote-side agent that replaces Pinggy and bore: it exposes a
port through the [Portal](https://github.com/gosuda/portal-tunnel) relay network.
No account, no card, no 60-minute timeout. With `-shell` it also brings its own
SSH server, so the remote needs nothing installed and no administrator rights.

Everything below authorizes this public key (the private half never leaves your
machine — a public key in a repo is not a secret):

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h anon
```

### Quick start — Windows remote, no Administrator

```powershell
mkdir C:\otd -Force
iwr https://raw.githubusercontent.com/julianponguta/opentunnel/main/dist/otd-windows-amd64.exe -OutFile C:\otd\otd.exe
Unblock-File C:\otd\otd.exe
C:\otd\otd.exe -shell -detach -authorized-key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h anon" -out C:\otd\addr.txt
```

Prints the address and returns to the prompt; the tunnel keeps running after the
window is closed (own process, no console):

```
4f2c9a1e8b7d6c5a4f3e2d1c0b9a8f7e6d5c4b3a.s-h.day:50007
[otd] en segundo plano (pid 4128), log: C:\otd\addr.txt.log
```

### Quick start — Linux remote, no sudo

```bash
curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/dist/otd-linux-amd64 -o /tmp/otd
chmod +x /tmp/otd
/tmp/otd -shell -detach -authorized-key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h anon" -out /tmp/otd.addr
```

ARM64 servers: `otd-linux-arm64`.

### Connect from your machine

```powershell
$h, $p = "4f2c9a1e8b7d6c5a4f3e2d1c0b9a8f7e6d5c4b3a.s-h.day:50007".Split(':')
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -p $p probe@$h "hostname && whoami"
```

The username is irrelevant in embedded mode (the key is the credential), and the
command line reaches `cmd.exe` / `sh` verbatim, so pipes and quotes work:

```powershell
... -p $p probe@$h 'powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"'
```

Handy wrapper:

```powershell
function otc { param([string]$Addr,[string]$Cmd="hostname && whoami")
  $h,$p = $Addr -split ':'
  ssh -i "$env:USERPROFILE\.ssh\id_ed25519" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -p $p probe@$h $Cmd }
```

Stop the tunnel with `Stop-Process -Name otd` (Windows) or `pkill -x otd` (Linux).

### If the box already has sshd

Drop `-shell` and the key — `otd` just relays `127.0.0.1:22`:

```powershell
C:\otd\otd.exe -detach -out C:\otd\addr.txt
```

No root needed either way: `otd` never binds port 22, it only dials it.

### No sshd on the box?

| situation | what to run |
|---|---|
| Linux/macOS with `sudo` | `connect.sh` (creates user + `openssh-server`), or `sudo apt install -y openssh-server` |
| Windows **with** Administrator | `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd` |
| **no admin at all** | `otd -shell` (embedded server, what the quick starts use) |

### Flags

| flag | meaning |
|---|---|
| `-port N` | local port to expose (default 22) |
| `-shell` | run an embedded SSH server instead of using the system sshd |
| `-authorized-key K` | public key allowed into the embedded server (or `-authorized-key-file`) |
| `-detach` | re-exec in its own process, print the address, return |
| `-out FILE` | file that receives the published `host:port` (removed at startup) |
| `-timeout D` | how long to wait for a validated endpoint (default 90s) |
| `-no-health-check` | publish the first announced endpoint without validating it |
| `-portal PATH` | reuse an existing `portal` binary instead of downloading |
| `-v` | stream the relay's output |

### How the endpoint is chosen

On first run it downloads the `portal` v2.7.4 binary into the user cache, then
announces one `tcp_addr` per relay in the public registry. **Only an endpoint
that completes a TCP dial *and* answers with an SSH banner is printed**, so a
dead relay or a cold `sshd` never reaches you:

```
[otd] descartado <id>.gosunuts.xyz:40006: dial tcp ...: i/o timeout
Tunnel: <id>.s-h.day:50003
```

Measured here: 23 MB download, 10-30 s to a validated endpoint, `gosunuts.xyz`
consistently dead while `s-h.day` / `kakashit.org` work, public hostname stable
per device and port changing between runs.

### Limits

- **No PTY** — interactive `ssh -t` gets a piped shell without line editing or
  job control. Use the system sshd when a real terminal matters.
- **No stdin forwarding** — commands run with an empty stdin; wiring the session
  into `exec.Cmd.Stdin` leaves Go's stdin copier parked, `Wait` expires on
  `WaitDelay`, the `exit-status` request fails with `EOF` and the client hangs.
- **Same privileges as the process** — launch `otd` elevated if the commands
  need it; anything reached through the tunnel is that account.
- The address is public; the key is the only gate. Anyone with the private key
  can run commands on that box while the tunnel is up.

---

## Limits (Pinggy/bore path)

- Free Pinggy tunnels expire after 60 minutes and get a random address each time.
- For persistent addresses use `otd` above (no expiry) or a self-hosted VPS relay (`ssh -R` with GatewayPorts).

---

## Requirements

- Remote: `otd` needs no admin, no root and no sshd; `connect.sh`/`connect.ps1` do
- Remote: root/sudo (Linux) or Administrator (Windows) for the Pinggy/bore path
- Remote: outbound HTTPS (port 443)
- Local: any `ssh` client (already installed everywhere)
