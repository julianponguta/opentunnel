---
name: opentunnel-connect
description: Establish SSH connections to remote servers via reverse tunnel. Use when user wants to connect to a remote server behind NAT/firewall without manual credential handling.
version: 1.0.0
---

# OpenTunnel Connect Skill

This skill enables OpenCode to establish SSH connections to remote servers through a reverse tunnel using bore.

## When to Use

Use this skill when:
- User wants to connect to a remote server via SSH
- The remote server is not directly accessible (behind NAT/firewall)
- User wants automatic connection without manual credential handling
- The user has sudo access on the remote server

## Prerequisites Check

**First time only:** Check if dependencies are installed:
- Node.js (for webhook server)
- npm packages: express
- bore CLI

If not installed, install with:
```bash
npm install express
```

The skill will create a flag file at `~/.opentunnel-installed` after first run to skip this check.

## Workflow

1. **User Request**: User asks to connect to a remote server
2. **Gather Info**: Ask for:
   - Minutes until auto-disconnect (default: 60)
   - User to connect as (default: root)
3. **Start Webhook**: Start local webhook server with bore tunnel
4. **Generate Command**: Provide command to run on remote server
5. **Wait for Credentials**: Wait for remote server to send credentials
6. **Connect**: Use ezssh to establish SSH connection
7. **Handle Disconnect**: If connection drops, regenerate connection command

## Starting Webhook Server

The skill should:
1. Check for `~/.opentunnel-installed` flag
2. If not present, install dependencies
3. Run `scripts/server.js` with Node.js
4. Wait for bore tunnel to establish
5. Extract the bore URL from output

## Command Format

Provide this command to user:
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect-skill/scripts/remote.sh" | sudo bash -s -- WEBHOOK_URL MINUTES USER
```

Example:
```
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect-skill/scripts/remote.sh" | sudo bash -s -- bore.pub:12345 30 root
```

## Receiving Credentials

When webhook receives POST at `/connect`:
```json
{
    "user": "root",
    "password": "existing",
    "host": "bore.pub",
    "port": 12345
}
```

## Connecting via SSH

Use ezssh_ssh_execute with:
- host: bore.pub
- port: [received port]
- username: [received user]
- password: [received password]

## Error Handling

- If webhook doesn't receive credentials within 60 seconds, inform user
- If SSH connection fails, offer to regenerate command
- If connection drops, user can run command again or skill can provide new command

## Related

- opentunnel: https://github.com/julianponguta/opentunnel
- ezssh-mcp: https://github.com/laomeifun/ezssh-mcp
- bore: https://github.com/ekzhang/bore
