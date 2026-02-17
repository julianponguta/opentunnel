---
name: opentunnel-connect
description: Establish SSH connections to remote servers via reverse tunnel using localhost.run + SSH key. NO BORE NEEDED on local machine.
version: 2.2.0
---

# OpenTunnel Connect Skill

This skill automatically establishes SSH connections to remote servers behind NAT/firewall.

## When to Use

Use when user wants to connect to a remote server behind NAT or firewall.

## IMPORTANT: Do NOT use bore on local machine!

This skill uses:
- **localhost.run** - For local webhook tunnel (works on Windows)
- **SSH Key** - For passwordless authentication (no password needed)
- **bore** - ONLY on remote server (auto-installed by remote.sh)

## DO NOT run server.js!

The entry point is `run.js`, NOT `server.js`.

## Setup

```bash
cd skills/opentunnel-connect && npm install
```

## Usage

### Step 1: Run the script

```bash
cd skills/opentunnel-connect/scripts && node run.js
```

NOT server.js! Use run.js!

This will:
1. Start localhost.run tunnel (via PowerShell on Windows)
2. Show command with your SSH key for remote server
3. Wait for credentials
4. Connect automatically via SSH key

### Step 2: Give command to user

The script outputs a command. User runs it on remote server.

### Step 3: Automatic connection

The script connects automatically when credentials arrive.

## Your SSH Key

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h julianponguta@gmail.com
```

Make sure your private key is in `~/.ssh/id_ed25519`

## Common Mistakes

- ❌ Don't run `node server.js` - that's for Linux only
- ✅ DO run `node run.js` - this works on Windows

## Files

- `scripts/run.js` - Main entry point (Windows + localhost.run + SSH key)
- `scripts/remote.sh` - Remote server script (installs bore, adds SSH key)
