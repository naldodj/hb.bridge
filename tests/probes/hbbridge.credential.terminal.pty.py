#!/usr/bin/env python3
"""Exercise the synthetic terminal probe on a POSIX pseudoterminal."""

import fcntl
import os
import pty
import select
import signal
import subprocess
import sys
import termios
import time


def run_terminal(executable, payload=None, interrupt=None):
    master, slave = pty.openpty()
    original = termios.tcgetattr(slave)

    def attach_terminal():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    process = subprocess.Popen(
        [executable], stdin=slave, stdout=slave, stderr=slave,
        preexec_fn=attach_terminal, close_fds=True,
    )
    transcript = bytearray()
    try:
        deadline = time.monotonic() + 15
        while b"Password: " not in transcript:
            if time.monotonic() >= deadline or process.poll() is not None:
                raise AssertionError("terminal prompt did not appear")
            ready, _, _ = select.select([master], [], [], 0.1)
            if ready:
                transcript.extend(os.read(master, 4096))
        if interrupt is not None:
            os.kill(process.pid, interrupt)
        else:
            for offset in range(0, len(payload), 128):
                os.write(master, payload[offset:offset + 128])
                time.sleep(0.002)
        while process.poll() is None:
            if time.monotonic() >= deadline:
                raise AssertionError("terminal probe timed out")
            ready, _, _ = select.select([master], [], [], 0.1)
            if ready:
                transcript.extend(os.read(master, 4096))
        while select.select([master], [], [], 0)[0]:
            transcript.extend(os.read(master, 4096))
        restored = termios.tcgetattr(slave)
        if restored != original:
            raise AssertionError(
                f"terminal attributes were not restored after {interrupt}: "
                f"lflag {original[3]:#x} -> {restored[3]:#x}"
            )
        return process.returncode, bytes(transcript)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(slave)
        os.close(master)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: terminal.pty.py <probe-executable>")
    executable = os.path.abspath(sys.argv[1])
    secret = "synthetic-é-secret".encode("utf-8")
    result = subprocess.run([executable], input=secret + b"\n", capture_output=True, timeout=15)
    if result.returncode != 1 or b"TERMINAL_PROBE_STATUS=1" not in result.stdout:
        raise AssertionError("redirected input was not rejected")
    if secret in result.stdout + result.stderr or b"Password: " in result.stderr:
        raise AssertionError("redirected input or a prompt appeared in output")

    code, output = run_terminal(executable, secret + b"\n")
    if code != 0 or b"TERMINAL_PROBE_MATCH" not in output or b"TERMINAL_MODE_RESTORED" not in output:
        raise AssertionError("UTF-8 terminal input did not round trip")
    if secret in output:
        raise AssertionError("terminal echoed the synthetic password")

    extra = b"synthetic-pasted-second-line"
    code, output = run_terminal(executable, secret + b"\n" + extra + b"\n")
    if code != 0 or b"TERMINAL_PROBE_MATCH" not in output or secret in output or extra in output:
        raise AssertionError("pasted input was echoed or changed the first line")

    for candidate in (b"  " + secret + b"  ", "synthetic-🚀-secret".encode("utf-8")):
        code, output = run_terminal(executable, candidate + b"\n")
        if code != 0 or b"TERMINAL_PROBE_MATCH" not in output or b"TERMINAL_MODE_RESTORED" not in output:
            raise AssertionError("terminal altered whitespace or Unicode input")
        if candidate in output:
            raise AssertionError("terminal echoed synthetic input")

    edited = "synthetic-é".encode("utf-8") + b"\x7f" + "é-secret\n".encode("utf-8")
    code, output = run_terminal(executable, edited)
    if code != 0 or b"TERMINAL_PROBE_MATCH" not in output or b"TERMINAL_MODE_RESTORED" not in output:
        raise AssertionError("UTF-8 backspace did not remove one character")
    if secret in output:
        raise AssertionError("terminal echoed the edited synthetic password")

    for invalid in (b"\n", b"\xff\n", b"\x1b[A\n"):
        code, output = run_terminal(executable, invalid)
        if code != 1 or b"TERMINAL_PROBE_STATUS=3" not in output or b"TERMINAL_MODE_RESTORED" not in output:
            raise AssertionError("empty or invalid UTF-8 input was not rejected")

    code, output = run_terminal(executable, b"x" * 4096 + b"\n")
    if code != 0 or b"TERMINAL_LIMIT_MATCH" not in output or b"TERMINAL_MODE_RESTORED" not in output:
        raise AssertionError("maximum-size password was not preserved")
    if b"x" * 64 in output:
        raise AssertionError("terminal echoed the maximum-size synthetic input")

    code, output = run_terminal(executable, b"x" * 4097 + b"\n")
    if code != 1 or b"TERMINAL_PROBE_STATUS=3" not in output or b"TERMINAL_MODE_RESTORED" not in output:
        raise AssertionError("oversized password was not rejected")
    if b"x" * 64 in output:
        raise AssertionError("terminal echoed oversized synthetic input")

    for interruption in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT, signal.SIGTSTP):
        code, output = run_terminal(executable, interrupt=interruption)
        if code != 1 or b"TERMINAL_PROBE_STATUS=4" not in output or b"TERMINAL_MODE_RESTORED" not in output:
            raise AssertionError("terminal signal did not cancel input after cleanup")
    print("Credential terminal PTY checks: 16; failures: 0")


if __name__ == "__main__":
    main()
