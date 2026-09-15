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
2. **Output**: Shows `host:port` + credentials
3. **You**: Connect with plain `ssh -p PORT user@host`

SSH traffic is end-to-end encrypted by your own `sshd`; the relay only sees ciphertext.

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
