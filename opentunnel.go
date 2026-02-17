package main

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
)

func main() {
	fmt.Println("========================================")
	fmt.Println("OpenTunnel Connect (Go Edition)")
	fmt.Println("========================================")

	tunnelCmd := exec.Command("ssh", "-R", "80:localhost:3000", "-o", "StrictHostKeyChecking=no", "-o", "ServerAliveInterval=60", "nokey@localhost.run")
	tunnelCmd.Stdout = os.Stdout
	tunnelCmd.Stderr = os.Stdout

	fmt.Println("\n[*] Starting localhost.run tunnel...")
	if err := tunnelCmd.Start(); err != nil {
		fmt.Printf("[-] Failed to start tunnel: %v\n", err)
		os.Exit(1)
	}

	reader := bufio.NewReader(os.Stdin)
	fmt.Println("\n[!] Now run this command on your REMOTE SERVER:")
	fmt.Println("curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- <host> <port> <user> <ssh_key>")
	fmt.Println("\n    Example:")
	fmt.Println("    curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/skills/opentunnel-connect/scripts/remote.sh | sudo bash -s -- 92ca79d79a606a.lhr.life 60 tunneluser \"ssh-ed25519 ...\"")
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
