---
name: opentunnel-connect
description: Establish SSH connections to remote servers via reverse tunnel using bore + localhost.run.
version: 1.3.0
---

# OpenTunnel Connect Skill

This skill enables OpenCode to establish SSH connections to remote servers through a reverse tunnel.

## Architecture

- **Webhook server** (local): Uses localhost.run to expose a webhook
- **Remote Uses bore to create SSH tunnel to bore server**:.pub

## When to Use

Use this skill when:
- User wants to connect to a remote server behind NAT/firewall
- Remote server cannot accept incoming SSH connections
- User has sudo access on the remote server

## Prerequisites

```bash
# Install dependencies
cd skills/opentunnel-connect && npm install
```

Required:
- Node.js
- express
- SSH access to remote server

## Workflow

### Step 1: Start Webhook Server (Local)

```bash
cd skills/opentunnel-connect/scripts && node server.js
```

Output:
```
========================================
Server running! Share this URL:
xxx.lhr.life
========================================
```

### Step 2: Provide Command to Remote User

Give this command to run on the remote server:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- WEBHOOK_URL MINUTES USER
```

Example:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- xxx.lhr.life 60 root
```

### Step 3: Receive Credentials

The webhook receives credentials via POST `/connect`:
```json
{
    "user": "root",
    "password": "otp_abc123...",
    "host": "bore.pub",
    "port": 12345
}
```

### Step 4: Connect via SSH

Use ezssh-mcp with:
- host: `bore.pub`
- port: [received port]
- username: [received user]
- password: [received password]

## Files

- `scripts/server.js` - Local webhook server (uses localhost.run)
- `scripts/remote.sh` - Remote server script (uses bore)
- `package.json` - Dependencies
