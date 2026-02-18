# OpenTunnel Connect - Agent Setup

This file contains instructions for AI agents to connect to remote servers behind NAT.

## Overview

OpenTunnel uses **bore** to create reverse SSH tunnels from remote servers.

## Setup

### Step 1: Install ezssh-mcp

```bash
npm install -g ezssh-mcp
```

### Step 2: Configure OpenCode MCP

Create or update `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "ezssh": {
      "command": "npx",
      "args": ["ezssh-mcp"]
    }
  }
}
```

### Step 3: Install opentunnel-connect Skill

```bash
npx skills add julianponguta/opentunnel/skills/opentunnel-connect
```

## Usage

When user wants to connect to a remote server behind NAT:

### Step 1: Ask Options

Ask user:
- Username? (default: tunneluser)
- Minutes? (default: 60)

### Step 2: Execute Binary

```powershell
powershell.exe -Command "& 'C:\Users\Julian\.config\opencode\skills\opentunnel-connect\opentunnel.exe' --user USERNAME --minutes MINUTES"
```

### Step 3: User Runs Command

The binary outputs a curl command. User runs it on remote server.

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

## Files

- `opentunnel.exe` - Windows binary for local machine
- `connect.sh` - Script to run on remote server
- `skills/opentunnel-connect/SKILL.md` - Skill definition
