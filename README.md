# OpenTunnel

One-command SSH tunnel to access remote servers instantly.

---

## Quick Start (Humans)

```bash
# Setup (once)
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@:-60}"; }' >> ~/.bashrc && source ~/.bashrc

# Use (each time you need to connect)
ot                  # 60 minutes, creates tunneluser with temp password
ot 30              # 30 minutes
ot root            # 60 minutes, uses root's existing password
ot 30 root        # 30 minutes, root
```

---

## How It Works

1. **Setup** (one-time) - Install skill + ezssh-mcp
2. **Use** (each time) - Start webhook → Give command to user → Connect

The AI agent cannot connect automatically because it needs the user to run a command on the remote server.

---

## For AI Agents

Copy and paste this to your agent:

```
Install the opentunnel-connect skill and configure ezssh-mcp by following: https://raw.githubusercontent.com/julianponguta/opentunnel/main/AGENT_SETUP.md
```
