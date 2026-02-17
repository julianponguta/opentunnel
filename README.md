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

Uses [localhost.run](https://localhost.run) to create SSH tunnels:

1. Runs `ssh -R 80:localhost:22 localhost.run` on remote server
2. Gets a public URL like `xxx.lhr.life`
3. You connect directly via that URL

---

## Requirements

- SSH installed on remote server
- No additional software needed (uses built-in SSH)

---

## For AI Agents

Copy and paste this to your agent:

```
Install the opentunnel-connect skill and configure ezssh-mcp by following: https://raw.githubusercontent.com/julianponguta/opentunnel/main/AGENT_SETUP.md
```
