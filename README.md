# OpenTunnel - AI Agent Setup

This file contains all the instructions AI agents need to set up and use OpenTunnel Connect.

## Overview

OpenTunnel creates SSH tunnels to remote servers using:
- **localhost.run** - For local webhook (on your machine)
- **bore** - For SSH tunnel (on remote server)

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

Run this on your local machine (Windows PowerShell or Linux):

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
    "port": 54321
  }
}
```

### Step 4: Connect via SSH

Use ezssh-mcp tool with these credentials:

- **host**: `bore.pub`
- **port**: [port from credentials]
- **username**: [user from credentials]
- **password**: [password from credentials]

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  TU MÁQUINA (localhost.run)                           │
│                                                         │
│  node server.js                                        │
│    └─► ssh -R 80:localhost:3000 nokey@localhost.run  │
│           └─► abc123.lhr.life                        │
│                                                         │
│  Webhook listening on /connect                        │
└─────────────────────────────────────────────────────────┘
                         │
                         │ HTTP
                         ▼
┌─────────────────────────────────────────────────────────┐
│  SERVIDOR REMOTO (bore)                                │
│                                                         │
│  remote.sh                                             │
│    └─► bore local 22 --to bore.pub                    │
│           └─► bore.pub:54321                          │
│    └─► POST http://abc123.lhr.life/connect           │
│           {user, password, host, port}                │
└─────────────────────────────────────────────────────────┘
```

## Files

- `scripts/server.js` - Local webhook server (uses localhost.run)
- `scripts/remote.sh` - Remote server script (uses bore)
- `scripts/SKILL.md` - Skill definition
