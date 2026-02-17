# OpenTunnel Connect - Agent Setup

This file contains detailed instructions for AI agents to set up and use OpenTunnel Connect.

## Overview

OpenTunnel Connect uses two services:
- **localhost.run** - For local webhook (exposes port via HTTP tunnel)
- **bore** - For remote SSH tunnel

## Setup Steps

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

## Usage

### Step 1: Start Webhook Server

```bash
cd skills/opentunnel-connect/scripts && node server.js
```

Wait for output like: `xxx.lhr.life`

### Step 2: Generate Command for User

```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- WEBHOOK_URL MINUTES USER
```

Example:
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- xxx.lhr.life 60 root
```

### Step 3: Wait for Credentials

Poll:
```bash
curl http://localhost:3000/status
```

When status is `ready`, credentials will be in the response:
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

Use ezssh_ssh_execute:
- host: `bore.pub`
- port: [received port]
- username: [received user]
- password: [received password]

## Files

- `skills/opentunnel-connect/scripts/server.js` - Webhook server
- `skills/opentunnel-connect/scripts/remote.sh` - Remote script
- `skills/opentunnel-connect/SKILL.md` - Skill definition
