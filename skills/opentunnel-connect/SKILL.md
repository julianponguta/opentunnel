---
name: opentunnel-connect
description: Establish SSH connections to remote servers via reverse tunnel using bore.
version: 1.2.0
---

# OpenTunnel Connect Skill

This skill enables OpenCode to establish SSH connections to remote servers through a reverse tunnel using [bore](https://github.com/ekzhang/bore).

## When to Use

Use this skill when:
- User wants to connect to a remote server behind NAT/firewall
- Remote server cannot accept incoming SSH connections
- User has sudo access on the remote server
- User wants automatic credential handling

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Linux | Supported | Native bore binary |
| macOS | Supported | Native bore binary |
| Windows (WSL) | Supported | Requires bore installed in WSL |
| Windows (Native) | Limited | Use WSL or Linux VM |

### Windows Setup

For Windows users, the recommended approach is:

1. Install WSL2 with Ubuntu
2. Install bore in WSL:
   ```bash
   wsl -e bash -c "curl -fsSL https://github.com/ekzhang/bore/releases/download/v0.6.0/bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /tmp && sudo mv /tmp/bore /usr/local/bin/ && sudo chmod +x /usr/local/bin/bore"
   ```
3. Run the webhook server from WSL:
   ```bash
   cd skills/opentunnel-connect/scripts && node server.js
   ```

Alternatively, run the webhook server on a Linux machine (local VM, cloud instance, or container).

## Prerequisites

The skill uses:
- Node.js (for local webhook server)
- `ezssh-mcp` for SSH connections
- Internet access for bore.pub tunnel

### Setup Steps

1. Install dependencies:
```bash
cd skills/opentunnel-connect && npm install
```

2. Ensure ezssh-mcp is configured in `~/.config/opencode/opencode.json`

## Workflow

### Step 1: Start Local Webhook Server

Run the server script (from Linux/WSL):
```bash
cd skills/opentunnel-connect/scripts && node server.js
```

The server will:
1. Install bore if needed
2. Start a bore tunnel
3. Output a URL like: `https://bore.pub:12345`

### Step 2: Provide Command to Remote User

Give this command to run on the remote server:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- bore.pub:PORT MINUTES USERNAME
```

Example:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh" | sudo bash -s -- bore.pub:12345 60 root
```

### Step 3: Wait for Credentials

The webhook will receive credentials via POST `/connect`:
```json
{
    "user": "tunneluser",
    "password": "otp_abc123...",
    "host": "bore.pub",
    "port": 12345
}
```

### Step 4: Connect via SSH

Use ezssh-mcp to connect:
```json
{
    "host": "bore.pub",
    "port": 12345,
    "username": "tunneluser",
    "password": "otp_abc123..."
}
```

## Command Reference

### Local (server.js)

```bash
# Default port 3000
node server.js

# Custom port
node server.js 8080
```

### Remote (remote.sh)

```bash
remote.sh <webhook_url> [minutes] [username]

# Arguments:
#   webhook_url   - bore.pub:PORT from local server
#   minutes       - Session duration (default: 60)
#   username      - SSH user to create (default: tunneluser)
```

## Troubleshooting

- **Windows Defender blocks bore.exe**: Use WSL or add exclusion
- **WSL network slow**: Run server on Linux VM instead
- **Connection timeout**: Check firewall settings on remote server
- **Credentials not received**: Verify remote script ran successfully

## Files

- `scripts/server.js` - Local webhook server
- `scripts/remote.sh` - Remote server script  
- `package.json` - Dependencies
