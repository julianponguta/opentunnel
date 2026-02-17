# OpenTunnel Connect - Agent Setup

This file contains detailed instructions for AI agents to set up and use OpenTunnel Connect.

## Overview

OpenTunnel Connect enables SSH connections to remote servers via reverse tunnel using bore. The remote server sends credentials back to the local machine through a webhook.

## Setup Steps

### Step 1: Install ezssh-mcp globally

Execute:
```bash
npm install -g ezssh-mcp
```

Verify installation:
```bash
ezssh --version
```

### Step 2: Configure OpenCode MCP

Read current config:
```bash
cat ~/.config/opencode/opencode.json
```

If file exists, add the mcp section. If not, create it with:

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

Write to `~/.config/opencode/opencode.json`

### Step 3: Install opentunnel-connect Skill

Execute:
```bash
npx skills add julianponguta/opentunnel/skills/opentunnel-connect
```

### Step 4: Install Skill Dependencies

Execute:
```bash
cd skills/opentunnel-connect && npm install
```

### Step 5: Test Webhook Server

Execute:
```bash
node skills/opentunnel-connect/scripts/server.js
```

Expected output: `Server running on bore.pub:XXXXX`

Save the port number (e.g., `12345` from `bore.pub:12345`)

## Usage Workflow

When user asks to connect to a remote server:

### Step 1: Start Webhook Server

Execute in background:
```bash
node skills/opentunnel-connect/scripts/server.js &
```

Wait for output: `bore.pub:PORT`

### Step 2: Generate Command for User

Provide this command to user (replace PORT with actual port):
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- bore.pub:PORT MINUTES USER
```

Example:
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- bore.pub:12345 30 root
```

### Step 3: Wait for Credentials

The webhook receives credentials at `/connect` endpoint. Poll:
```bash
curl http://localhost:3000/status
```

When status is `ready`, credentials will be in the response:
```json
{
  "status": "ready",
  "credentials": {
    "user": "root",
    "password": "existing",
    "host": "bore.pub",
    "port": 12345
  }
}
```

### Step 4: Connect via SSH

Use ezssh_ssh_execute tool with:
- host: `bore.pub`
- port: [received port]
- username: [received user]
- password: [received password]

### Step 5: Handle Disconnection

If SSH connection drops:
- Generate new command for user
- User runs it on remote server
- Reconnect with new credentials

## Files Reference

- `skills/opentunnel-connect/scripts/server.js` - Webhook server (Node.js)
- `skills/opentunnel-connect/scripts/remote.sh` - Script to run on remote server
- `skills/opentunnel-connect/SKILL.md` - Skill definition

## Troubleshooting

### MCP not working

Check OpenCode config:
```bash
cat ~/.config/opencode/opencode.json
```

Ensure mcp section is present and valid.

### Webhook not receiving credentials

- Verify remote server has internet access
- Check bore tunnel is established
- Verify port is correct in command

### SSH connection fails

- Verify credentials are correct
- Check user exists on remote server
- Ensure SSH is running on remote server
