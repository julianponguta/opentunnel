---
name: opentunnel-connect
description: Establish SSH connections to remote servers via reverse tunnel.
version: 1.4.0
---

# OpenTunnel Connect Skill

This skill automatically establishes SSH connections to remote servers using:
- **localhost.run** - For local webhook
- **bore** - For SSH tunnel on remote

## When to Use

Use when user wants to connect to a remote server behind NAT/firewall.

## Workflow

### Step 1: Start Webhook Server

Run on your machine:
```bash
cd skills/opentunnel-connect/scripts && node server.js
```

Wait for URL output like: `abc123.lhr.life`

### Step 2: Provide Command to User

Give this command to user to run on remote server:
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- WEBHOOK_URL MINUTES USER
```

Example:
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- abc123.lhr.life 60 root
```

### Step 3: Wait for Credentials

Poll:
```bash
curl http://localhost:3000/status
```

Response:
```json
{
  "status": "ready",
  "credentials": {
    "user": "root",
    "password": "otp_xxx",
    "host": "bore.pub",
    "port": 12345
  }
}
```

### Step 4: Connect via ezssh-mcp

```json
{
  "host": "bore.pub",
  "port": 12345,
  "username": "root",
  "password": "otp_xxx"
}
```

## Setup

```bash
npm install -g ezssh-mcp
npx skills add julianponguta/opentunnel/skills/opentunnel-connect
cd skills/opentunnel-connect && npm install
```

Configure ezssh in `~/.config/opencode/opencode.json`.
