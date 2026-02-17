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

Two services working together:
- **bore** - Creates SSH tunnel from remote server to bore.pub
- **localhost.run** - Exposes webhook locally for receiving credentials

### Without webhook (manual):

1. Run script on remote server
2. Get `bore.pub:PORT`
3. Connect: `ssh -p PORT user@bore.pub`

### With webhook (AI agents):

See "For AI Agents" section below.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  TU MÁQUINA (localhost.run)                            │
│                                                         │
│  node server.js ──► localhost.run ──► xxx.lhr.life    │
│         ▲                                              │
│         │ POST /connect                                │
│         │ {user, password, host, port}               │
└─────────┼───────────────────────────────────────────────┘
          │
          │ HTTP (puerto 80)
          │
┌─────────▼───────────────────────────────────────────────┐
│  SERVIDOR REMOTO                                       │
│                                                         │
│  remote.sh ──► bore ──► bore.pub:PORT ──► SSH        │
│       │                                                 │
│       └──► useradd + password                           │
└─────────────────────────────────────────────────────────┘
```

---

## Requirements

- SSH installed on remote server
- No additional software needed (bore auto-installs)
- For webhook: Node.js + express

---

## For AI Agents

### Setup (one-time)

```bash
# Install ezssh-mcp globally
npm install -g ezssh-mcp

# Configure OpenCode MCP
# Add to ~/.config/opencode/opencode.json:
{
  "mcp": {
    "ezssh": {
      "command": "npx",
      "args": ["ezssh-mcp"]
    }
  }
}

# Install skill
npx skills add julianponguta/opentunnel/skills/opentunnel-connect

# Install dependencies
cd skills/opentunnel-connect && npm install
```

### Usage Flow

**Step 1: Start webhook (your machine)**
```bash
cd skills/opentunnel-connect/scripts && node server.js
```
Output: `xxx.lhr.life`

**Step 2: Give command to remote user**
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- WEBHOOK_URL MINUTES USER
```

Example:
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- abc123.lhr.life 60 root
```

**Step 3: Receive credentials**

Webhook receives POST at `/connect`:
```json
{
  "user": "root",
  "password": "otp_abc123...",
  "host": "bore.pub",
  "port": 12345
}
```

**Step 4: Connect via ezssh-mcp**

```json
{
  "host": "bore.pub",
  "port": 12345,
  "username": "root",
  "password": "otp_abc123..."
}
```

---

## Files

- `connect.sh` - Standalone script for humans (no webhook)
- `skills/opentunnel-connect/scripts/server.js` - Webhook server
- `skills/opentunnel-connect/scripts/remote.sh` - Remote server script
