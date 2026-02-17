# OpenTunnel - SSH Tunnel Service

> **For Claude:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a one-command SSH tunnel solution using bore for remote access to servers without installing OpenCode locally.

**Architecture:** Single bash script that auto-installs bore, generates temporary SSH credentials, creates cleanup job, and starts tunnel.

**Tech Stack:** Bash, SSH, bore (https://github.com/ekzhang/bore)

---

## Overview

The user wants to access remote servers via SSH tunnel without installing OpenCode on those servers. The solution is:

1. Run one command on the remote server
2. Command auto-installs bore if needed
3. Generates temporary SSH key
4. Creates cleanup job (auto-delete after X hours)
5. Starts bore tunnel exposing port 22
6. Outputs ready-to-use SSH command

---

## Usage

```bash
# On remote server (one command):
curl -fsSL https://get.opentunnel.dev | bash

# Output:
# ========================================================
#              OPENTUNNEL READY
# ========================================================
# 
# Tunnel: bore.pub:18347
# User:   root
# 
# Copy and run this on your local machine:
# ------------------------------------------------------------
# ssh -o StrictHostKeyChecking=no -i /tmp/opentunnel_key root@18347.bore.pub
# ------------------------------------------------------------
#
# Key saved at: /tmp/opentunnel_key
# Expires in: 60 minutes
# ========================================================
```

---

## Requirements

- Linux server with SSH already running
- curl installed
- sudo/root access (for creating temp user)
- Internet connection (to download bore)

---

## Features

1. **Auto-install bore** - Downloads bore binary if not present
2. **Generate SSH key** - Creates temporary ed25519 key
3. **Configure SSH** - Add key to authorized_keys
4. **Start tunnel** - Run bore to expose port 22
5. **Auto-cleanup** - Delete everything after X hours
6. **Single output** - Print ready SSH command

---

## File Structure

```
opentunnel/
├── connect.sh           # Main script (served via HTTP)
├── SPEC.md              # This specification
└── docs/
    └── plans/
        └── 2026-02-17-opentunnel-plan.md
```

---

## Security Considerations

- SSH key is temporary (auto-deleted)
- User is temporary
- Only one session at a time
- Cleanup happens automatically
- No persistent access left behind
