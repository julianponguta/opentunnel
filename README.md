# OpenTunnel - AI Agent Setup

This file contains all the instructions AI agents need to set up and use OpenTunnel Connect.

## Overview

OpenTunnel creates SSH tunnels to remote servers using **bore** for both:
- Local webhook server
- Remote SSH tunnel

Both connect through `bore.pub` - no additional services needed.

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

```bash
cd skills/opentunnel-connect/scripts && node server.js
```

Wait for output like:
```
========================================
Server running! Share this URL:
bore.pub:12345
========================================
```

Copy the port number (e.g., `12345`).

### Step 2: Provide Command to Remote User

Give this command to the user to run on the remote server:

```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- WEBHOOK_PORT MINUTES USER
```

Replace:
- `WEBHOOK_PORT` - The port from Step 1 (e.g., `12345`)
- `MINUTES` - Session duration (default: 60)
- `USER` - Username to create (default: tunneluser)

**Example:**
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- 12345 60 root
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
│  TU MÁQUINA                                           │
│                                                         │
│  node server.js                                        │
│    └─► bore local 3000 --to bore.pub                  │
│           └─► bore.pub:12345                          │
│                                                         │
│  Webhook listening on /connect                        │
└─────────────────────────────────────────────────────────┘
                         │
                         │ HTTP
                         ▼
┌─────────────────────────────────────────────────────────┐
│  SERVIDOR REMOTO                                       │
│                                                         │
│  remote.sh                                             │
│    └─► bore local 22 --to bore.pub                    │
│           └─► bore.pub:54321                          │
│    └─► POST http://bore.pub:12345/connect            │
│           {user, password, host, port}                │
└─────────────────────────────────────────────────────────┘
```

## Files

- `scripts/server.js` - Local webhook server
- `scripts/remote.sh` - Remote server script
- `scripts/SKILL.md` - Skill definition
