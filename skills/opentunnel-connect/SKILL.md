---
name: opentunnel-connect
description: Establish SSH connections to remote servers via reverse tunnel using bore + localhost.run + SSH key.
version: 2.0.0
---

# OpenTunnel Connect Skill

This skill automatically establishes SSH connections to remote servers behind NAT/firewall.

## When to Use

Use when user wants to connect to a remote server that:
- Is behind NAT or firewall
- Cannot accept incoming SSH connections
- Has sudo access

## How It Works

1. **Start webhook** - Runs locally using localhost.run
2. **Generate command** - Creates command with your SSH key
3. **User runs command** - On remote server
4. **Server connects back** - Using bore tunnel + adds SSH key
5. **Automatic login** - Connects via SSH key (no password needed)

## Prerequisites

- SSH key pair (public key in `~/.ssh/id_ed25519.pub`)
- Node.js installed
- Remote server with SSH and sudo access

## Setup

```bash
cd skills/opentunnel-connect && npm install
```

## Usage

### Step 1: Run the Script

```bash
cd skills/opentunnel-connect/scripts && node run.js
```

### Step 2: Give Command to User

The script outputs a command. User runs it on remote server.

### Step 3: Automatic Connection

The skill connects automatically when credentials are received.

## SSH Key

Your public key is included in the command automatically:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h julianponguta@gmail.com
```

Make sure your private key is in `~/.ssh/id_ed25519`

## Troubleshooting

- **Permission denied**: Ensure your SSH key is added to remote server
- **Connection timeout**: Check firewall settings on remote server
- **bore not found**: The script auto-installs bore on the remote server
