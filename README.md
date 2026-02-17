# OpenTunnel Connect

Connect to remote servers behind NAT/firewall using reverse SSH tunnels.

---

# Basic Usage (Without Skill)

## Step 1: Start Local Tunnel

Run on your **local machine** (Windows):

```powershell
.\opentunnel.exe --user root --minutes 60
```

The binary will:
- **Automatically create** an SSH key if you don't have one
- Start localhost.run tunnel
- Output the curl command for remote

## Step 2: Run Command on Remote Server

The script will output a curl command. Run it on your **remote server**:

```bash
curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- <URL> 60 root --daemon "<YOUR_SSH_PUBLIC_KEY>"
```

## Step 3: Get Tunnel Info

The remote server will output:
```
Tunnel: bore.pub:12345
```

## Step 4: Connect

Copy that info and connect:
```bash
ssh -i ~/.ssh/id_ed25519 root@bore.pub -p 12345
```

---

# OpenCode Skill Usage

## For AI Agents

When user wants to connect to a remote server behind NAT:

### Step 1: Ask Options

Ask user:
- Username? (options: "tunneluser", "root")
- Minutes? (default: 60)

### Step 2: Execute Binary

The binary automatically:
- Creates SSH key if missing
- Reads SSH key from ~/.ssh/id_ed25519.pub

```powershell
powershell.exe -Command "& 'C:\Users\Julian\.config\opencode\skills\opentunnel-connect\opentunnel.exe' --user USERNAME --minutes MINUTES"
```

### Step 3: User Runs Command

Give curl command to user to run on **remote server**.

### Step 4: Get Tunnel Info

User provides: `bore.pub:PORT`

The remote server outputs: `Tunnel: bore.pub:12345`

### Step 5: Connect with ezssh

```javascript
ezssh_ssh_execute({
  command: "hostname && uptime",
  hosts: ["bore.pub"],
  port: PORT,
  username: "USERNAME",
  privateKeyPath: "C:/Users/Julian/.ssh/id_ed25519"
})
```

---

# Files

- `opentunnel.exe` - Standalone binary (Windows, no dependencies)
- `opentunnel.go` - Source code
- `skills/opentunnel-connect/scripts/remote.sh` - Remote server script

---

# Troubleshooting

- **No SSH key**: Binary automatically creates one in ~/.ssh/
- **SSH key not working**: Run the curl command on remote - it adds the key automatically
- **Connection refused**: Wait a few seconds for bore to start on remote
- **Tunnel expired**: Run the curl command again on remote
