//go:build !windows

package main

import "os/exec"

func shellCmd(raw string) *exec.Cmd {
	return exec.Command("/bin/sh", "-c", raw)
}
