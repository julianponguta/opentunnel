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

`cmd/otd` is the remote-side agent that replaces Pinggy and bore: it exposes the
machine's SSH port through the [Portal](https://github.com/gosuda/portal-tunnel)
relay network. No account, no card, no 60-minute timeout.

```bash
go build -o otd ./cmd/otd
./otd                  # exposes 127.0.0.1:22
./otd -port 22 -v      # -port, -timeout, -no-health-check, -portal <path>
```

Prebuilt binaries (committed under `dist/`), Linux x86-64/ARM64 and Windows x64:

```bash
# Linux remote
curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/dist/otd-linux-amd64 -o /tmp/otd \
  && chmod +x /tmp/otd && /tmp/otd
```
```powershell
# Windows remote
iwr https://raw.githubusercontent.com/julianponguta/opentunnel/main/dist/otd-windows-amd64.exe -OutFile $env:TEMP\otd.exe
Unblock-File $env:TEMP\otd.exe; & $env:TEMP\otd.exe
```

No root needed: `otd` only dials `127.0.0.1:22`, it never binds port 22.

### No sshd on the box?

`otd` exposes a port; something must answer on it.

| situation | what to run |
|---|---|
| Linux/macOS with `sudo` | `connect.sh` (sets up user + `openssh-server`), or just `sudo apt install -y openssh-server` |
| Windows **with** Administrator | `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd` |
| **no admin at all** | `otd -shell` — SSH server embedded in the same process |

```bash
./otd -shell                                  # authorizes the current user's ~/.ssh/*.pub
./otd -shell -authorized-key "ssh-ed25519 AAAA..."
./otd -shell -authorized-key-file /path/authorized_keys
```

Embedded mode is key-only (no passwords), binds `127.0.0.1` on a random port,
uses no PAM, installs nothing and runs with the caller's privileges. Fully
non-interactive: `ssh -p PORT user@host "uname -a"`, exit codes included.
Two limits, both intentional:

- **No PTY** — an interactive `ssh -t` gets a piped shell without line editing
  or job control. Use the system sshd path when a real terminal matters.
- **No stdin forwarding** — commands run with an empty stdin. Wiring the session
  into `exec.Cmd.Stdin` leaves Go's stdin copier parked when the child exits
  without reading, `Wait` expires on `WaitDelay`, the `exit-status` request then
  fails with `EOF` and the client hangs until it times out.


On first run it downloads the `portal` v2.7.4 binary into the user cache. The
agent announces one `tcp_addr` per relay in the public registry; **otd prints only
an endpoint that completes a TCP dial *and* answers with an SSH banner**, so a
dead relay or a cold `sshd` never reaches you:

```
[otd] descartado <id>.gosunuts.xyz:40006: dial tcp ...: i/o timeout
Tunnel: <id>.s-h.day:50003
```

Paste that `host:port` into `opentunnel.exe` as usual — the local side is still
plain `ssh`.

Measured from this repo's machine: 23 MB download, ~20-30 s to a validated
endpoint, one of the two registry relays (`gosunuts.xyz`) consistently dead, and
the public hostname stays stable per device while the port changes between runs.

---

## Limits

- Free tunnels expire after 60 minutes and get a random address each time.
- For persistent addresses: Pinggy Pro token or a self-hosted VPS relay (`ssh -R` with GatewayPorts) — same design.

---

## Requirements

- Remote: Linux server or Windows with Admin/PowerShell
- Remote: root/sudo (Linux) or Administrator (Windows)
- Remote: outbound HTTPS (port 443)
- Local: any `ssh` client (already installed everywhere)
