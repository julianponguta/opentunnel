# OpenTunnel Connect

Connect AI agents to remote servers behind NAT/firewall.

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

---

## For LLM Agents

When user requests remote server access, follow these steps:

### Step 1: Ask
```
- Username? (default: tunneluser, or root)
- Duration? (default: 60 min)
```

### Step 2: Execute Binary
```powershell
& "$env:USERPROFILE\.config\opencode\skills\opentunnel-connect\opentunnel.exe" --user USERNAME --minutes MINUTES
```

### Step 3: Give Command to User
Binary outputs a curl command. User runs it on **remote server**:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 60 root "ssh-ed25519..."
```

### Step 4: Receive Tunnel Info
User provides: `bore.pub:PORT`

### Step 5: Connect
```javascript
ezssh_ssh_execute({
  command: "hostname && uptime",
  hosts: ["bore.pub"],
  port: PORT,
  username: "USERNAME",
  privateKeyPath: "C:/Users/Julian/.ssh/id_ed25519"
})
```

---

## Output Format

The binary outputs credentials:
```
--- CREDENTIALS ---
HOST_PORT=bore.pub:12345
USER=root
--- END CREDENTIALS ---
```

Parse this to extract connection info.

---

## Quick Commands (for users)

Users can install `ot` function on their servers:
```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> ~/.bashrc && source ~/.bashrc
```

Then run:
- `ot` → 60 min, tunneluser
- `ot root` → 60 min, root
- `ot 30 root` → 30 min, root
