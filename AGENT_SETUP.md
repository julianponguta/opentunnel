# OpenTunnel Connect

Connect AI agents to remote servers behind NAT/firewall.

---

## Install

### OpenCode (local)
```bash
npx skills add julianponguta/opentunnel/skills/opentunnel-connect
```

### Global (any agent)
```bash
npx skills add julianponguta/opentunnel/skills/opentunnel-connect --global
```

### Manual
Download skill to `~/.config/opencode/skills/opentunnel-connect/`

---

## Prerequisites

**Required MCP:** ezssh for SSH connections

Add to `~/.config/opencode/opencode.json`:
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

## Agent Workflow

When user requests remote server access:

### 1. Ask
```
- Username? (default: tunneluser, or root)
- Duration? (default: 60 min)
```

### 2. Execute Binary
```powershell
& "$env:USERPROFILE\.config\opencode\skills\opentunnel-connect\opentunnel.exe" --user USERNAME --minutes MINUTES
```

### 3. Give Command to User
Binary outputs a curl command. User runs it on **remote server**:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 60 root "ssh-ed25519..."
```

### 4. Receive Tunnel Info
User provides: `bore.pub:PORT`

### 5. Connect
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

The binary outputs credentials in this format:
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
