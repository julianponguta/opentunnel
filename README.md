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

## How It Works

1. Run `ot` on the remote server
2. Script installs **bore** automatically
3. Creates a temporary SSH user
4. Starts tunnel to `bore.pub:PORT`
5. Connect from your machine: `ssh -p PORT user@bore.pub`
6. Auto-cleanup after the specified time

---

## OpenCode Skill

For AI agents to automatically connect to remote servers.

### Setup

```bash
# Install skill
npx skills add julianponguta/opentunnel/skills/opentunnel-connect

# Install dependencies
cd skills/opentunnel-connect && npm install

# Configure ezssh-mcp in ~/.config/opencode/opencode.json
{
  "mcp": {
    "ezssh": {
      "command": "npx",
      "args": ["ezssh-mcp"]
    }
  }
}
```

### How It Works

1. Start webhook server locally: `node skills/opentunnel-connect/scripts/server.js`
2. Get a URL like `xxx.lhr.life`
3. Run remote script with that URL
4. Webhook receives credentials automatically
5. AI connects via ezssh-mcp

---

## For AI Agents

```
Follow the instructions at: https://raw.githubusercontent.com/julianponguta/opentunnel/main/README.md
```
