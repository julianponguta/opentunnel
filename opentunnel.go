package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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
		}
	}

	fmt.Println("========================================")
	fmt.Println("OpenTunnel Connect")
	fmt.Println("========================================")

	fmt.Println("\n[OK] Your SSH key ready:")
	fmt.Printf("    %s\n", sshKey)

	fmt.Println("\n========================================")
	fmt.Println("RUN THIS COMMAND ON REMOTE SERVER:")
	fmt.Println("========================================")
	fmt.Printf("curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh | sudo bash -s -- %s \"%s\"\n", user, sshKey)
	fmt.Println("========================================")
	fmt.Println("\n[OK] After running, the remote will give you:")
	fmt.Println("    bore.pub:PORT")
	fmt.Println("\n[INPUT] Enter the tunnel info from remote (e.g., bore.pub:12345):")

	reader := bufio.NewReader(os.Stdin)
	tunnelInfo, _ := reader.ReadString('\n')
	tunnelInfo = strings.TrimSpace(tunnelInfo)

	if tunnelInfo == "" {
		fmt.Println("[-] No tunnel info provided")
		os.Exit(1)
	}

	fmt.Println("\n--- CREDENTIALS ---")
	fmt.Printf("HOST_PORT=%s\n", tunnelInfo)
	fmt.Printf("USER=%s\n", user)
	fmt.Println("--- END CREDENTIALS ---")
}
