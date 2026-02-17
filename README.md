# OpenTunnel - AI Agent Setup

This file contains all the instructions AI agents need to set up and use OpenTunnel Connect.

## Overview

OpenTunnel creates SSH tunnels to remote servers using:
- **bore** - For SSH tunnel from remote to bore.pub
- **localhost.run** - For local webhook to receive credentials

## Setup (One-Time)

### Step 1: Install ezssh-mcp globally

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

### Step 4: Install Dependencies

```bash
cd skills/opentunnel-connect && npm install
```

## Usage Flow

When user wants to connect to a remote server:

### Step 1: Start Webhook Server (Your Machine)

Run this on your local machine:

```bash
cd skills/opentunnel-connect/scripts && node server.js
```

Wait for output like:
```
========================================
Server running! Share this URL:
abc123.lhr.life
========================================
```

Copy the URL (e.g., `abc123.lhr.life`).

### Step 2: Provide Command to Remote User

Give this command to the user to run on the remote server:

```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- WEBHOOK_URL MINUTES USER
```

Replace:
- `WEBHOOK_URL` - The URL from Step 1 (e.g., `abc123.lhr.life`)
- `MINUTES` - Session duration (default: 60)
- `USER` - Username to create (default: tunneluser)

**Example:**
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- abc123.lhr.life 60 root
```

### Step 3: Wait for Credentials

Poll the status endpoint:

```bash
curl http://localhost:3000/status
```

When ready, response will be:
```json
{
  "status": "ready",
  "credentials": {
    "user": "root",
    "password": "otp_abc123...",
    "host": "bore.pub",
    "port": 12345
  }
}
```

### Step 4: Connect via SSH

Use ezssh-mcp tool with these credentials:

- **host**: `bore.pub`
- **port**: [port from credentials]
- **username**: [user from credentials]
- **password**: [password from credentials]

## Command Reference

### Local (server.js)

```bash
# Default port 3000
node server.js

# Custom port
node server.js 8080
```

### Remote (remote.sh)

```bash
remote.sh <webhook_url> [minutes] [username]

# Example:
# remote.sh abc123.lhr.life 60 root
```

## Files

- `skills/opentunnel-connect/scripts/server.js` - Local webhook server
- `skills/opentunnel-connect/scripts/remote.sh` - Remote server script
- `skills/opentunnel-connect/SKILL.md` - Skill definition

## Troubleshooting

- **Webhook not receiving credentials**: Check remote server has internet access
- **Connection fails**: Verify credentials and try again
- **bore not installing**: Manually install: `curl -fsSL https://getbore.io | bash`
