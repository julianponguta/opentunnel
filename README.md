# OpenTunnel Connect

Connect to remote servers behind NAT/firewall using reverse SSH tunnels.

---

# Basic Usage

## Step 1: Get Your SSH Key

The binary automatically reads or creates your SSH key from `~/.ssh/id_ed25519`

## Step 2: Run Command on Remote Server

Run this on your **remote server**:

```bash
curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- root --daemon "ssh-ed25519 AAAA..."
```

- `root` = username
- `--daemon` = run in background and exit
- `ssh-ed25519...` = your public key

## Step 3: Get Tunnel Info

The remote will output:
```
Tunnel: bore.pub:12345
```

## Step 4: Connect

```bash
ssh -i ~/.ssh/id_ed25519 root@bore.pub -p 12345
```

---

# OpenCode Skill

## Flow

1. **Ask user**: username and minutes
2. **Execute**: opentunnel.exe --user USERNAME --minutes MINUTES
3. **User runs** curl command on remote server
4. **User provides**: bore.pub:PORT
5. **Connect**: ezssh_ssh_execute with credentials

## Credentials Format

```
--- CREDENTIALS ---
HOST_PORT=bore.pub:12345
USER=root
--- END CREDENTIALS ---
```

## ezssh Connection

```javascript
ezssh_ssh_execute({
  command: "hostname && uptime",
  hosts: ["bore.pub"],
  port: 12345,
  username: "root",
  privateKeyPath: "C:/Users/Julian/.ssh/id_ed25519"
})
```
