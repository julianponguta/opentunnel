# OpenTunnel

One-command SSH tunnel to access remote servers instantly.

---

## For Humans

### Quick Start

```bash
# Setup (once)
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@:-60}"; }' >> ~/.bashrc && source ~/.bashrc

# Use
ot                  # 60 minutes, creates tunneluser with temp password
ot 30              # 30 minutes
ot root            # 60 minutes, uses root's existing password
ot 30 root        # 30 minutes, root
```

### Direct Install

```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- 30
```

---

## For AI Agents (OpenCode, Claude, Cursor)

Install the opentunnel-connect skill and configure ezssh-mcp by following: https://raw.githubusercontent.com/julianponguta/opentunnel/main/AGENT_SETUP.md

---

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

## Requirements

- Linux server with SSH running
- sudo/root access
- Internet connection

## Security

- Auto-expires after configured minutes
- Temporary users are deleted automatically
- Existing users keep their password unchanged
- No persistent access left behind
