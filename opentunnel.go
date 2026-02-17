package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"strings"
)

func main() {
	reader := bufio.NewReader(os.Stdin)

	fmt.Println("========================================")
	fmt.Println("OpenTunnel Connect (Go Edition)")
	fmt.Println("========================================")
	fmt.Println()

	defaultSSHKey := "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzn4bIIjxL+VO6WCjrvF+rxt3LVi4s4X57ZwP4wnG1h julianponguta@gmail.com"

	fmt.Print("[?] Your SSH key (press Enter to use default): ")
	sshKey, _ := reader.ReadString('\n')
	sshKey = strings.TrimSpace(sshKey)

	if sshKey == "" {
		sshKey = defaultSSHKey
		fmt.Println("[*] Using default SSH key")
	} else {
		fmt.Println("[*] Using provided SSH key")
	}

	fmt.Print("[?] Remote server user (default: tunneluser): ")
	user, _ := reader.ReadString('\n')
	user = strings.TrimSpace(user)
	if user == "" {
		user = "tunneluser"
	}

	fmt.Println("\n[*] Starting localhost.run tunnel...")

	tunnelCmd := exec.Command("ssh", "-R", "80:localhost:3000", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=60", "nokey@localhost.run")
	tunnelCmd.Stdout = os.Stdout
	tunnelCmd.Stderr = os.Stdout

	if err := tunnelCmd.Start(); err != nil {
		fmt.Printf("[-] Failed to start tunnel: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("\n[!] Waiting for tunnel URL from localhost.run output above...")
	fmt.Print("[?] Enter the tunnel URL (e.g., 03747080ea3e6e.lhr.life): ")
	tunnelURL, _ := reader.ReadString('\n')
	tunnelURL = strings.TrimSpace(tunnelURL)

	for tunnelURL == "" {
		fmt.Print("[?] Please enter the tunnel URL: ")
		tunnelURL, _ = reader.ReadString('\n')
		tunnelURL = strings.TrimSpace(tunnelURL)
	}

	fmt.Println("\n[!] RUN THIS COMMAND ON YOUR REMOTE SERVER:")
	fmt.Println("========================================")
	fmt.Printf("curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- %s 60 %s \"%s\"\n", tunnelURL, user, sshKey)
	fmt.Println("========================================")
	fmt.Println("\n[+] Press ENTER when remote is connected...")
	reader.ReadString('\n')

	fmt.Println("\n[*] Waiting for SSH connection on port 2222...")

	listener, err := net.Listen("tcp", ":2222")
	if err != nil {
		fmt.Printf("[-] Failed to listen on port 2222: %v\n", err)
		tunnelCmd.Process.Kill()
		os.Exit(1)
	}
	defer listener.Close()

	conn, err := listener.Accept()
	if err != nil {
		fmt.Printf("[-] Failed to accept connection: %v\n", err)
		tunnelCmd.Process.Kill()
		os.Exit(1)
	}
	defer conn.Close()

	fmt.Println("[+] Remote connected! Forwarding to local SSH (port 22)...")

	sshConn, err := net.Dial("tcp", "localhost:22")
	if err != nil {
		fmt.Printf("[-] Failed to connect to local SSH: %v\n", err)
		os.Exit(1)
	}
	defer sshConn.Close()

	done := make(chan bool, 2)

	go func() {
		io.Copy(conn, sshConn)
		done <- true
	}()

	go func() {
		io.Copy(sshConn, conn)
		done <- true
	}()

	<-done
	fmt.Println("\n[!] Connection closed.")
}
