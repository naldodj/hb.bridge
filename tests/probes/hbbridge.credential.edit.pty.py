#!/usr/bin/env python3
"""Exercise the isolated credential edit fixture with synthetic terminal input."""

from pathlib import Path
import runpy
import signal
import subprocess
import sys
import tempfile


def main():
    if len(sys.argv) != 2 or not sys.platform.startswith("linux"):
        raise SystemExit("Usage: edit.pty.py <protected SQL test executable> (Linux)")
    executable = str(Path(sys.argv[1]).resolve(strict=True))
    terminal = Path(__file__).with_name("hbbridge.credential.terminal.pty.py")
    run_terminal = runpy.run_path(str(terminal))["run_terminal"]
    password = "  synthetic-é-replacement  ".encode("utf-8")
    checks = 0
    for case in ("publish", "redirect", "cancel", "conflict"):
        args = ["--terminal-update-fixture=" + case]
        with tempfile.TemporaryDirectory(prefix="hbbridge-edit-", dir="/tmp") as directory:
            def concurrent_edit():
                target = Path(directory, "credential-publish-fixture.ini")
                with target.open("ab") as stream:
                    stream.write(b"# synthetic concurrent edit\n")

            if case == "redirect":
                result = subprocess.run([executable, *args], input=password + b"\n", cwd=directory,
                                        capture_output=True, timeout=15)
                code, output = result.returncode, result.stdout + result.stderr
            else:
                code, output = run_terminal(executable, password + b"\n", args=args, cwd=directory,
                                            interrupt=signal.SIGINT if case == "cancel" else None,
                                            on_prompt=concurrent_edit if case == "conflict" else None)
            if code or b"Protected SQL credential checks=3; failures=0" not in output:
                raise AssertionError("Credential edit fixture failed for " + case)
            if password.strip() in output or b"synthetic old password" in output or b"enc:v1:" in output:
                raise AssertionError("Credential data appeared in output")
            if output.count(b"Password: ") != (0 if case == "redirect" else 1):
                raise AssertionError("Unexpected terminal prompt count")
            if list(Path(directory).iterdir()):
                raise AssertionError("Credential fixture did not release its files")
        checks += 1
        print("PASS terminal update " + case)
    print(f"Credential edit PTY cases: {checks}; failures: 0")


if __name__ == "__main__":
    main()
