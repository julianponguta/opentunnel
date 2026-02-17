---
name: opentunnel-connect
description: Establish SSH connections to remote servers via reverse tunnel using bore + localhost.run + SSH key.
version: 2.1.0
---

# OpenTunnel Connect Skill

This skill automatically establishes SSH connections to remote servers behind NAT/firewall.

## When to Use

Use when user wants to connect to a remote server that is behind NAT or firewall.

## Prerequisites

- SSH key pair (public key in `~/.ssh/id_ed25519.pub`)
- Node.js installed
- Remote server with SSH and sudo access

## Setup

```bash
cd skills/opentunnel-connect && npm install
```

## How It Works

1. **Run run.js** - This starts localhost.run tunnel
2. **Generate command** - Shows command with your SSH key
3. **User runs on remote** - Server adds SSH key + starts bore tunnel
4. **Automatic connection** - Connects via SSH key (no password needed)

## Usage

Run the script directly:

```bash
cd skills/opentunnel-connect/scripts && node run.js
```

This will:
- Start localhost.run tunnel
- Show command for remote server
- Wait for credentials
- Connect automatically via SSH

## SSH Key

Your public key is included in the command automatically.

## Files

- `scripts/run.js` - Main entry point (uses localhost.run + SSH key)
- `scripts/remote.sh` - Remote server script
- `scripts/server.js` - Alternative webhook server (for Linux)
