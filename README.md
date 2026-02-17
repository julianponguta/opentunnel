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

With webhook (for AI agents):
```bash
ot 60 root bore.pub:12345   # 60 min, root, webhook at bore.pub:12345
```

---

## How It Works

Uses two services:
- **bore** - Creates SSH tunnel from remote server to bore.pub
- **localhost.run** - Optional webhook for AI agents to receive credentials

### Without webhook (manual):
1. Run script on remote server
2. Get `bore.pub:PORT`
3. Connect: `ssh -p PORT user@bore.pub`

### With webhook (AI agents):
1. Start webhook server locally (uses localhost.run)
2. Run script on remote with webhook URL
3. Webhook receives credentials automatically
4. AI connects via ezssh-mcp

---

## Requirements

- SSH installed on remote server
- No additional software needed (bore auto-installs)

---

## For AI Agents

Copy and paste this to your agent:

```
Install the opentunnel-connect skill and configure ezssh-mcp by following: https://raw.githubusercontent.com/julianponguta/opentunnel/main/AGENT_SETUP.md
```
