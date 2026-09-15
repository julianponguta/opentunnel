# OpenTunnel Connect

Connect AI agents to remote servers behind NAT/firewall via SSH over a Pinggy TCP tunnel.

---

## Installation

### Option A: Let an LLM do it

Paste this into any LLM agent (Claude Code, OpenCode, Cursor, etc.):

```
Install the opentunnel-connect skill by running: npx skills add julianponguta/opentunnel/skills/opentunnel-connect
Then configure ezssh MCP in ~/.config/opencode/opencode.json with: { "mcp": { "ezssh": { "command": ["npx", "-y", "ezssh-mcp"], "enabled": true, "type": "local" } } }
```

### Option B: Manual setup

1. **Install the skill:**
   ```bash
   npx skills add julianponguta/opentunnel/skills/opentunnel-connect
   ```

2. **Configure ezssh MCP** in `~/.config/opencode/opencode.json`:
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

No other prerequisites: both ends use the stock `ssh` client, and the tunnel is plain TCP.

---

## For LLM Agents

When user requests remote server access, follow these steps:

### Step 1: Ask
```
- Username? (default: tunneluser, or root / Administrator)
- Duration? (default: 60 min)
```

### Step 2: Execute Binary

**Windows:**
```powershell
& "$env:USERPROFILE\.config\opencode\skills\opentunnel-connect\opentunnel.exe" --user USERNAME --minutes MINUTES
```

**Linux/macOS:**
```bash
~/.config/opencode/skills/opentunnel-connect/opentunnel --user USERNAME --minutes MINUTES
```

The binary sanitizes the SSH key (type + key only, no email/comment ever sent).
Use `--no-key` for password mode if the user prefers nothing of their key leaves the machine.

### Step 3: Give Command to User
Binary outputs the remote command. User runs it on the **remote server**:

Linux remote:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 60 root "ssh-ed25519 AAAA..."
```

Windows remote (PowerShell as Admin):
```powershell
irm https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.ps1 -OutFile $env:TEMP\ot.ps1; & $env:TEMP\ot.ps1 -Minutes 60 -User Administrator -SshKey "ssh-ed25519 AAAA..."
```

### Step 4: Receive Tunnel Info
User provides: `host:port` (e.g. `abc-12-34-56.run.pinggy-free.link:33045`)

### Step 5: Connect

**Option A: via ezssh (preferred for agents):**

**Windows:**
```javascript
ezssh_ssh_execute({
  command: "hostname && uptime",
  hosts: ["TUNNEL_HOST"],
  port: TUNNEL_PORT,
  username: "USERNAME",
  privateKeyPath: process.env.USERPROFILE + "/.ssh/id_ed25519"
})
```

**Linux/macOS:**
```javascript
ezssh_ssh_execute({
  command: "hostname && uptime",
  hosts: ["TUNNEL_HOST"],
  port: TUNNEL_PORT,
  username: "USERNAME",
  privateKeyPath: process.env.HOME + "/.ssh/id_ed25519"
})
```

**Option B: plain ssh:**
```bash
ssh -i ~/.ssh/id_ed25519 -p TUNNEL_PORT USERNAME@TUNNEL_HOST
```

Verify with `hostname && uptime` first.

---

## Output Format

The binary outputs credentials:
```
--- CREDENTIALS ---
HOST_PORT=abc-12-34-56.run.pinggy-free.link:33045
USER=root
--- END CREDENTIALS ---
```

Parse this to extract connection info.

---

## Quick Commands (for users)

Users can install `ot` function on their Linux servers:
```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> ~/.bashrc && source ~/.bashrc
```

Then run:
- `ot` → 60 min, tunneluser
- `ot root` → 60 min, root
- `ot 30 root` → 30 min, root
