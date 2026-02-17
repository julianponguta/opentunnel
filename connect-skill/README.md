# OpenTunnel Connect

Reverse SSH tunnel skill for OpenCode.

## Install

```bash
npm install
```

## Files

- `server.js` - Webhook server (runs on local machine)
- `remote.sh` - Script to run on remote server
- `SKILL.md` - Skill definition for OpenCode
- `AGENTS.md` - Quick reference for agents

## Usage

1. Run `node server.js` on local machine
2. Get the bore URL from output
3. Provide command to remote server user
4. Wait for credentials
5. Connect via ezssh-mcp
