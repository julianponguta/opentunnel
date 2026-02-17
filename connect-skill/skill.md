# OpenTunnel Connect Skill

## Overview

This skill enables OpenCode to establish SSH connections to remote servers through a reverse tunnel. The user runs a command on the remote server, which sends credentials back to OpenCode via webhook, enabling automatic SSH connection.

## When to Use

Use this skill when:
- User wants to connect to a remote server via SSH
- The remote server is not directly accessible (behind NAT/firewall)
- User wants automatic connection without manual credential handling
- The user has sudo access on the remote server

## Workflow

1. **User Request**: User asks to connect to a remote server
2. **Gather Info**: Skill asks for:
   - Minutes until auto-disconnect (default: 60)
   - User to connect as (default: root)
3. **Start Webhook**: Skill starts local webhook server with bore tunnel
4. **Generate Command**: Skill provides the command to run on remote server
5. **Wait for Credentials**: Skill waits for remote server to send credentials
6. **Connect**: Skill uses ezssh to establish SSH connection
7. **Handle Disconnect**: If connection drops, skill can regenerate connection command

## Prerequisites

- OpenCode environment with Node.js
- ezssh-mcp configured for SSH connections
- Remote server must have:
  - Internet access (to download script)
  - SSH service running
  - sudo/root access

## Usage

When user requests SSH connection to remote server:

```
User: "Conectar a mi servidor"
Skill: "¿Cuántos minutos? ¿Qué usuario?"
User: "30 minutos, root"
Skill: [Starts webhook, provides command]
```

## Command to Provide to User

```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect-skill/remote.sh" -o /tmp/ot.sh && sudo bash /tmp/ot.sh WEBHOOK_URL MINUTES USER
```

Example:
```bash
curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect-skill/remote.sh" -o /tmp/ot.sh && sudo bash /tmp/ot.sh bore.pub:12345 30 root
```

## Implementation Notes

### Starting Webhook Server

The skill should:
1. Run `server.js` with Node.js
2. Wait for bore tunnel to establish
3. Extract the bore URL from output

### Parsing Credentials

When webhook receives credentials:
```json
{
    "user": "root",
    "password": "existing",
    "host": "bore.pub",
    "port": 12345
}
```

### Connecting via SSH

Use ezssh_ssh_execute with:
- host: bore.pub
- port: [received port]
- username: [received user]
- password: [received password]

## Error Handling

- If webhook doesn't receive credentials within timeout, inform user
- If SSH connection fails, offer to regenerate command
- If connection drops, user can run command again or skill can provide new command

## Related

- opentunnel project: https://github.com/julianponguta/opentunnel
- ezssh-mcp: https://github.com/laomeifun/ezssh-mcp
- bore: https://github.com/ekzhang/bore
