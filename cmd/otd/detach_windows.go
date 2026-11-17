//go:build windows

package main

import (
	"os/exec"
	"syscall"
)

// DETACHED_PROCESS: no console, so closing the PowerShell window does not take
// the tunnel down. CREATE_NEW_PROCESS_GROUP keeps Ctrl-C in the parent from
// reaching it.
func detachProc(c *exec.Cmd) {
	c.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: 0x00000008 | 0x00000200,
		HideWindow:    true,
	}
}
