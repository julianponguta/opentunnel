# OpenTunnel Connect - Agent Setup

For AI agents to connect to remote servers behind NAT.

## Quick Setup

### Step 1: Configure ezssh MCP

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

### Step 2: Install Skill

```bash
npx skills add julianponguta/opentunnel/skills/opentunnel-connect
```

## Usage

When user says "connect to my remote server":

### Step 1: Ask Options

Ask user:
- Username? (default: tunneluser)
- Minutes? (default: 60)

### Step 2: Run Binary

```powershell
powershell.exe -Command "& 'C:\Users\Julian\.config\opencode\skills\opentunnel-connect\opentunnel.exe' --user USERNAME --minutes MINUTES"
```

### Step 3: User Runs Command

The binary outputs a curl command. Give it to the user to run on remote server.

Example:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 60 root "ssh-ed25519..."
```

### Step 4: Get Tunnel Info

User provides: `bore.pub:PORT`

### Step 5: Connect with ezssh

```javascript
ezssh_ssh_execute({
  command: "hostname && uptime",
  hosts: ["bore.pub"],
  port: PORT,
  username: "USERNAME",
  privateKeyPath: "C:/Users/Julian/.ssh/id_ed25519"
})
```

## Credentials Format

```
--- CREDENTIALS ---
HOST_PORT=bore.pub:12345
USER=root
--- END CREDENTIALS ---
```

## Common Commands

- `ot` - 60 min, tunneluser
- `ot root` - 60 min, root (uses existing SSH key or password)
- `ot 30` - 30 min, tunneluser

## Files

- `opentunnel.exe` - Windows binary
- `connect.sh` - Script for remote server
- `skills/opentunnel-connect/SKILL.md` - Skill definition
