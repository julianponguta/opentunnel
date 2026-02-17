# OpenTunnel

One-command SSH tunnel to access remote servers instantly.

## Quick Start (Recommended)

### 1. Setup (once)

```bash
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@:-60}"; }' >> ~/.bashrc && source ~/.bashrc
```

### 2. Use

```bash
ot                  # 60 minutes, creates tunneluser with temp password
ot 30              # 30 minutes, tunneluser with temp password
ot root            # 60 minutes, uses root's existing password
ot ubuntu          # 60 minutes, uses ubuntu's existing password
ot 30 root         # 30 minutes, root
ot root 30         # 30 minutes, root (any order)
```

## Direct Install (No Setup)

```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 30
```

## How It Works

| User | Behavior |
|------|----------|
| New user (e.g., `ot`) | Creates `tunneluser` with temporary password |
| Existing user (e.g., `root`, `ubuntu`) | Uses existing password |

## Output

```
========================================================
              OPENTUNNEL READY
========================================================

User:     root
Password: (your existing password)

Connect with:
------------------------------------------------------------
ssh -p 12345 root@bore.pub
------------------------------------------------------------

Expires in: 60 minutes
========================================================
```

## Connect

```bash
ssh -p PORT USER@bore.pub
# Enter password when prompted
```

## Requirements

- Linux server with SSH running
- sudo/root access
- Internet connection

## Security

- Auto-expires after configured minutes
- Temporary users are deleted automatically
- Existing users keep their password unchanged
- No persistent access left behind
