package main

import (
	"crypto/subtle"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/gliderlabs/ssh"
	gossh "golang.org/x/crypto/ssh"
)

// Embedded SSH server (-shell).
//
// For boxes with no system sshd and no admin rights to install one: key-only
// auth, no PAM, no service, no root. Sessions run with the same privileges as
// this process, which is exactly enough for command execution.
//
// Limitation by design: no PTY. Non-interactive `ssh host "cmd"` works fully;
// an interactive `ssh -t` gets a piped shell without line editing or job
// control. Use the system sshd path when a real terminal is required.

func startEmbeddedSSH(keys []gossh.PublicKey) (string, error) {
	srv := &ssh.Server{
		Addr: "127.0.0.1:0",
		PublicKeyHandler: func(_ ssh.Context, key ssh.PublicKey) bool {
			for _, want := range keys {
				if subtle.ConstantTimeCompare(key.Marshal(), want.Marshal()) == 1 {
					return true
				}
			}
			return false
		},
		Handler: handleSession,
	}
	ln, err := net.Listen("tcp", srv.Addr)
	if err != nil {
		return "", err
	}
	go func() {
		if err := srv.Serve(ln); err != nil {
			logf("ssh embebido: %v", err)
		}
	}()
	return ln.Addr().String(), nil
}

func handleSession(s ssh.Session) {
	// RawCommand, not Command(): Command() shlex-splits the request, so quotes
	// are gone by the time we rebuild it and `powershell -c "a | b"` reaches
	// cmd.exe as `powershell -c a | b` (the pipe splits at cmd level).
	var c *exec.Cmd
	if raw := strings.TrimSpace(s.RawCommand()); raw != "" {
		c = shellCmd(raw)
	} else {
		c = exec.Command(defaultShell())
	}
	c.Stdout, c.Stderr = s, s.Stderr()
	c.Env = os.Environ()

	// No stdin forwarding on purpose. Wiring the session (directly or through a
	// pipe) leaves exec's stdin copier parked when the child exits without
	// reading: Wait then expires on WaitDelay, the exit-status request fails with
	// EOF and the client hangs until it times out. Measured both variants. We
	// drain the client's stdin so the channel never backs up.
	go func() { _, _ = io.Copy(io.Discard, s) }()

	code := 0
	if err := c.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			code = ee.ExitCode()
		} else {
			fmt.Fprintf(s.Stderr(), "%v\n", err)
			code = 127
		}
	}
	if err := s.Exit(code); err != nil {
		_ = s.Close()
	}
}

func defaultShell() string {
	if runtime.GOOS == "windows" {
		if com := os.Getenv("COMSPEC"); com != "" {
			return com
		}
		return "cmd.exe"
	}
	if sh := os.Getenv("SHELL"); sh != "" {
		return sh
	}
	return "/bin/sh"
}

// loadKeys accepts an inline authorized_keys line and/or a file. With neither,
// it falls back to the operator's own public keys, the same ones the local
// opentunnel client already uses.
func loadKeys(inline, file string) ([]gossh.PublicKey, error) {
	var raw []string
	if strings.TrimSpace(inline) != "" {
		raw = append(raw, inline)
	}
	if file != "" {
		data, err := os.ReadFile(file)
		if err != nil {
			return nil, err
		}
		raw = append(raw, string(data))
	}
	if len(raw) == 0 {
		home, _ := os.UserHomeDir()
		for _, name := range []string{"id_ed25519.pub", "id_ecdsa.pub", "id_rsa.pub"} {
			data, err := os.ReadFile(filepath.Join(home, ".ssh", name))
			if err == nil {
				raw = append(raw, string(data))
			}
		}
	}

	var keys []gossh.PublicKey
	for _, blob := range raw {
		for _, line := range strings.Split(blob, "\n") {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			k, _, _, _, err := gossh.ParseAuthorizedKey([]byte(line))
			if err != nil {
				return nil, fmt.Errorf("llave inválida %q: %w", line, err)
			}
			keys = append(keys, k)
		}
	}
	if len(keys) == 0 {
		return nil, fmt.Errorf("sin llave autorizada: pasá -authorized-key o -authorized-key-file")
	}
	return keys, nil
}
