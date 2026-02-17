package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
)

func getSSHKey() string {
	homeDir := os.Getenv("USERPROFILE")
	if homeDir == "" {
		homeDir = os.Getenv("HOME")
	}

	sshDir := filepath.Join(homeDir, ".ssh")
	keyPath := filepath.Join(sshDir, "id_ed25519.pub")
	privateKeyPath := filepath.Join(sshDir, "id_ed25519")

	if _, err := os.Stat(privateKeyPath); os.IsNotExist(err) {
		fmt.Println("[*] SSH key not found, generating one...")

		os.MkdirAll(sshDir, 0700)

		cmd := exec.Command("ssh-keygen", "-t", "ed25519", "-f", privateKeyPath, "-N", "", "-C", "opentunnel")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stdout
		cmd.Run()

		fmt.Println("[+] SSH key generated!")
	}

	data, err := os.ReadFile(keyPath)
	if err == nil {
		return strings.TrimSpace(string(data))
	}

	return ""
}

func main() {
	user := "tunneluser"
	minutes := 60
	sshKey := getSSHKey()

	if sshKey == "" {
		fmt.Println("[-] Error: Could not generate or find SSH key")
		os.Exit(1)
	}

	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		if args[i] == "--user" && i+1 < len(args) {
			user = args[i+1]
			i++
		} else if args[i] == "--ssh-key" && i+1 < len(args) {
			sshKey = args[i+1]
			i++
		} else if args[i] == "--minutes" && i+1 < len(args) {
			fmt.Sscanf(args[i+1], "%d", &minutes)
			i++
		}
	}

	fmt.Println("========================================")
	fmt.Println("OpenTunnel Connect")
	fmt.Println("========================================")

	tunnelCmd := exec.Command("ssh", "-R", "80:localhost:3000", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=60", "-o", "LogLevel=ERROR", "nokey@localhost.run")

	tunnelOutput, err := tunnelCmd.StdoutPipe()
	if err != nil {
		fmt.Printf("[-] Failed to create pipe: %v\n", err)
		os.Exit(1)
	}

	tunnelCmd.Stderr = tunnelCmd.Stdout

	if err := tunnelCmd.Start(); err != nil {
		fmt.Printf("[-] Failed to start tunnel: %v\n", err)
		os.Exit(1)
	}

	scanner := bufio.NewScanner(tunnelOutput)
	tunnelURL := ""

	for scanner.Scan() {
		line := scanner.Text()
		re := regexp.MustCompile(`(\w+)\.lhr\.life`)
		matches := re.FindStringSubmatch(line)
		if len(matches) > 1 {
			tunnelURL = matches[0]
			break
		}
	}

	if tunnelURL == "" {
		fmt.Println("[-] Could not detect tunnel URL")
		os.Exit(1)
	}

	fmt.Printf("\n[OK] Tunnel: %s\n", tunnelURL)
	fmt.Println("\n========================================")
	fmt.Println("RUN THIS COMMAND ON REMOTE SERVER:")
	fmt.Println("========================================")
	fmt.Printf("curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- %s %d %s --daemon \"%s\"\n", tunnelURL, minutes, user, sshKey)
	fmt.Println("========================================")
	fmt.Println("\n[OK] After running, the remote will give you:")
	fmt.Println("    Tunnel: bore.pub:PORT")
	fmt.Println("\n[INPUT] Enter the tunnel info from remote (e.g., bore.pub:12345):")

	reader := bufio.NewReader(os.Stdin)
	tunnelInfo, _ := reader.ReadString('\n')
	tunnelInfo = tunnelInfo[:len(tunnelInfo)-1]

	fmt.Println("\n--- CREDENTIALS ---")
	fmt.Printf("HOST_PORT=%s\n", tunnelInfo)
	fmt.Printf("USER=%s\n", user)
	fmt.Println("--- END CREDENTIALS ---")
}
