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

### Setup Instructions

When user wants to connect to a remote server via SSH, follow these steps:

#### Step 1: Install ezssh-mcp

Run this command to install ezssh-mcp globally:
```bash
npm install -g ezssh-mcp
```

#### Step 2: Configure OpenCode

Add this to `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "ezssh": {
      "command": "npx",
      "args": ["ezssh-mcp"]
    }
  }
}
```

Or run:
```bash
# Edit ~/.config/opencode/opencode.json and add the mcp section
```

#### Step 3: Install the opentunnel-connect Skill

```bash
npx skills add julianponguta/opentunnel/skills/opentunnel-connect

# Then install dependencies
cd skills/opentunnel-connect && npm install
```

#### Step 4: Use the Skill

When user asks to connect to a remote server:

1. Start the webhook server: `node skills/opentunnel-connect/scripts/server.js`
2. Get the bore URL from output
3. Provide the command to user
4. Wait for credentials
5. Connect using ezssh_ssh_execute

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
