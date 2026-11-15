//go:build windows

package main

import (
	"os/exec"
	"syscall"
)

// shellCmd hands the raw command line to cmd.exe without Go re-quoting it.
// exec.Command("cmd.exe", "/c", raw) makes Go escape inner quotes as \" which
// cmd does not understand, so `echo "a b"` printed \"a b\" and PowerShell
// arguments arrived mangled.
func shellCmd(raw string) *exec.Cmd {
	c := exec.Command("cmd.exe")
	c.SysProcAttr = &syscall.SysProcAttr{CmdLine: "cmd.exe /s /c " + raw}
	return c
}
