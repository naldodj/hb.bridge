#!/usr/bin/env python3
"""Probe Windows sharing rules on disposable synthetic files only."""
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile


READ = 0x80000000
WRITE = 0x40000000
SHARE_READ = 0x1
SHARE_WRITE = 0x2
SHARE_DELETE = 0x4
SHARE_ALL = SHARE_READ | SHARE_WRITE | SHARE_DELETE
SHARING_VIOLATION = 32
INVALID_HANDLE = wintypes.HANDLE(-1).value


def open_file(path, access, share):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    create = kernel.CreateFileW
    create.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
                       wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    create.restype = wintypes.HANDLE
    handle = create(str(path), access, share, None, 3, 0x80, None)
    if handle == INVALID_HANDLE:
        return None, ctypes.get_last_error()
    return handle, 0


def close_file(handle):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL
    if not kernel.CloseHandle(handle):
        raise ctypes.WinError(ctypes.get_last_error())


def child(mode, path, stage=None):
    if mode == "--replace":
        module = runpy.run_path(str(Path(__file__).with_name("hbbridge.credential.atomic.probe.py")))
        try:
            module["replace_file"](Path(path), Path(stage), use_posix=True)
        except OSError as error:
            return error.winerror
        return 0
    access = WRITE if mode == "--write" else READ
    handle, error = open_file(path, access, SHARE_ALL)
    if handle is not None:
        close_file(handle)
    return error


def main():
    if os.name != "nt":
        raise SystemExit("This synthetic probe requires Windows")
    if len(sys.argv) >= 3 and sys.argv[1] in ("--write", "--read", "--replace"):
        print("STATUS=" + str(child(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)))
        return
    checks = 0
    with tempfile.TemporaryDirectory(prefix="hbbridge-sharing-test-") as directory:
        target = Path(directory) / "configuration.ini"
        stage = Path(directory) / "replacement.ini"
        original = b"[fixture]\nvalue=old\n"
        replacement = b"[fixture]\nvalue=new\n"
        target.write_bytes(original)
        stage.write_bytes(replacement)

        def check(condition, description):
            nonlocal checks
            checks += 1
            if not condition:
                raise AssertionError(description)
            print("PASS " + description)

        def run(mode, *paths):
            result = subprocess.run([sys.executable, __file__, mode, *(str(path) for path in paths)],
                                    capture_output=True, text=True, check=True, timeout=20)
            if not result.stdout.strip().startswith("STATUS="):
                raise AssertionError("Unexpected child result")
            return int(result.stdout.strip().split("=", 1)[1])

        writer, error = open_file(target, WRITE, SHARE_ALL)
        check(writer is not None and error == 0, "existing writer opened")
        try:
            guard, error = open_file(target, READ, SHARE_READ | SHARE_DELETE)
            if guard is not None:
                close_file(guard)
            check(guard is None and error == SHARING_VIOLATION, "existing writer blocks guard")
        finally:
            close_file(writer)

        guard, error = open_file(target, READ, SHARE_READ | SHARE_DELETE)
        check(guard is not None and error == 0, "guard opened")
        try:
            check(run("--write", target) == SHARING_VIOLATION, "guard blocks another process from opening for write")
            check(run("--read", target) == 0, "guard permits a compatible reader")
            check(run("--replace", target, stage) == 0 and target.read_bytes() == replacement,
                  "delete sharing permits another process to replace the path")
        finally:
            close_file(guard)
        check(run("--write", target) == 0, "writer can open after guard closes")

        target.write_bytes(original)
        stage.write_bytes(replacement)
        reader, error = open_file(target, READ, SHARE_READ | SHARE_WRITE)
        check(reader is not None and error == 0, "reader without delete sharing opened")
        try:
            check(run("--replace", target, stage) == SHARING_VIOLATION and
                  target.read_bytes() == original and stage.read_bytes() == replacement,
                  "reader without delete sharing refuses replacement without changing files")
        finally:
            close_file(reader)

        guard, error = open_file(target, READ, SHARE_READ)
        check(guard is not None and error == 0, "guard without delete sharing opened")
        try:
            check(run("--write", target) == SHARING_VIOLATION and
                  run("--replace", target, stage) == SHARING_VIOLATION and
                  target.read_bytes() == original and stage.read_bytes() == replacement,
                  "guard without delete sharing blocks writing and replacement")
        finally:
            close_file(guard)
        check(run("--replace", target, stage) == 0 and target.read_bytes() == replacement,
              "replacement succeeds after exclusive guard closes")
        print(f"Credential sharing synthetic checks: {checks}; failures: 0")


if __name__ == "__main__":
    main()
