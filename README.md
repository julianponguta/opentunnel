# OpenTunnel

One-command SSH tunnel to access remote servers without installing anything.

## Quick Start

On your remote server, run:

```bash
curl -fsSL https://get.opentunnel.dev | sudo bash
```

Or download and run locally:

```bash
curl -fsSL https://get.opentunnel.dev -o connect.sh
chmod +x connect.sh
sudo ./connect.sh
```

## What It Does

1. Installs `bore` (if not present)
2. Generates temporary SSH key
3. Creates temporary user
4. Starts tunnel to bore.pub
5. Sets auto-cleanup timer (1 hour)

## Output

You'll get a command like:

```bash
ssh -o StrictHostKeyChecking=no -i /tmp/opentunnel_key_abc123 tunneluser@12345.bore.pub
```

Run this on your local machine to connect.

## Requirements

- Linux server with SSH running
- sudo/root access
- Internet connection

## Security

- Key auto-expires after 1 hour
- User and key are deleted automatically
- No persistent access left behind
- Only one session at a time
