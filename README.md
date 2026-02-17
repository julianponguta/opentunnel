# OpenTunnel - AI Agent Setup

This file contains all the instructions AI agents need to set up and use OpenTunnel Connect.

## Overview

OpenTunnel creates SSH tunnels to remote servers using:
- **localhost.run** - For local webhook (on your machine)
- **bore** - For SSH tunnel (on remote server)
- **SSH Key** - For passwordless authentication

## Setup (One-Time)

### Step 1: Get Your SSH Public Key

```bash
cat ~/.ssh/id_ed25519.pub
```

If you don't have one, create it:
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

### Step 2: Install Dependencies

```bash
cd skills/opentunnel-connect && npm install
```

### Step 3: Configure ezssh-mcp (Optional)

If you want to use ezssh-mcp for SSH connections, add to `~/.config/opencode/opencode.json`:
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

## Usage Flow

When user wants to connect to a remote server:

### Step 1: Run the Script

```bash
cd skills/opentunnel-connect/scripts && node run.js
```

### Step 2: Give Command to User

The script will output a command like:

```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- URL MINUTES USER "SSH_KEY"
```

### Step 3: Automatic Connection

The script will:
1. Wait for credentials from the remote server
2. Connect automatically via SSH using your key
3. Show the connection result

## Your SSH Key

Your public key (needed for automatic login):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h julianponguta@gmail.com
```

## Troubleshooting

- **SSH key not working**: Make sure the remote server has your key in `~/.ssh/authorized_keys`
- **Tunnel not established**: Check that bore is installed on remote server
- **Credentials not received**: Verify the webhook URL is correct

## Files

- `scripts/run.js` - Main entry point for AI agents
- `scripts/server.js` - Webhook server
- `scripts/remote.sh` - Remote server script
- `skills/opentunnel-connect/SKILL.md` - Skill definition
