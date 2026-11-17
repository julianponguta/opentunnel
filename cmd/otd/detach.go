package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// runDetached starts the tunnel in its own process, waits for the address file
// and prints it, so one command both backgrounds the tunnel and tells you where
// to connect. The child survives the terminal being closed.
func runDetached(outFile string, timeout time.Duration) error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	var args []string
	for _, a := range os.Args[1:] {
		if a == "-detach" || a == "--detach" {
			continue
		}
		args = append(args, a)
	}

	logPath, errPath := filepath.Join(os.TempDir(), "otd.log"), filepath.Join(os.TempDir(), "otd.err")
	if outFile != "" {
		logPath, errPath = outFile+".log", outFile+".err"
	}
	lf, err := os.Create(logPath)
	if err != nil {
		return err
	}
	defer lf.Close()
	ef, err := os.Create(errPath)
	if err != nil {
		return err
	}
	defer ef.Close()

	cmd := exec.Command(exe, args...)
	cmd.Stdout, cmd.Stderr = lf, ef
	detachProc(cmd)
	if err := cmd.Start(); err != nil {
		return err
	}
	pid := cmd.Process.Pid

	if outFile == "" {
		fmt.Printf("[otd] en segundo plano (pid %d). Sin -out no hay direccion que leer.\n", pid)
		return nil
	}

	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if b, err := os.ReadFile(outFile); err == nil {
			if addr := strings.TrimSpace(string(b)); addr != "" {
				fmt.Println(addr)
				fmt.Printf("[otd] en segundo plano (pid %d), log: %s\n", pid, logPath)
				return nil
			}
		}
		time.Sleep(500 * time.Millisecond)
	}

	tail := ""
	if b, err := os.ReadFile(errPath); err == nil {
		lines := strings.Split(strings.TrimSpace(string(b)), "\n")
		if len(lines) > 3 {
			lines = lines[len(lines)-3:]
		}
		tail = strings.TrimSpace(strings.Join(lines, "\n"))
	}
	if tail == "" {
		tail = "(sin salida)"
	}
	return fmt.Errorf("pid %d sin direccion tras %s; ultimas lineas de %s:\n%s", pid, timeout, errPath, tail)
}
