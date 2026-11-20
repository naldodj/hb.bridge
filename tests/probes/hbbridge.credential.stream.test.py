#!/usr/bin/env python3
"""Test stream enumeration with disposable synthetic Windows files."""
import os
import ctypes
from ctypes import wintypes
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile


def main():
    if os.name != "nt" or len(sys.argv) != 2:
        raise SystemExit("Usage: stream.test.py <probe executable> (Windows only)")
    executable = str(Path(sys.argv[1]).resolve(strict=True))
    with tempfile.TemporaryDirectory(prefix="hbbridge-stream-test-") as directory:
        root = Path(directory)
        target = root / "configuração.ini"
        target.write_bytes(b"synthetic configuration")

        def check(path, expected, description, mode=None):
            path_hex = str(path).encode("utf-8").hex()
            args = [executable, path_hex] + ([mode] if mode else [])
            result = subprocess.run(args, capture_output=True, text=True,
                                    check=True, timeout=20)
            prefix = "SACL_STATUS" if mode == "sacl" else "STREAM_STATUS"
            if result.stdout.strip() != f"{prefix}={expected}":
                raise AssertionError(description + ": unexpected status " + repr(result.stdout.strip()))
            print("PASS " + description)

        check(target, 0, "single unnamed stream and Unicode path")
        stream = Path(str(target) + ":hbbridge-test")
        stream.write_bytes(b"synthetic alternate stream")
        if stream.read_bytes() != b"synthetic alternate stream":
            raise AssertionError("Alternate stream fixture was not written")
        check(target, 3, "alternate stream is rejected")
        stream.unlink()
        check(target, 0, "removed alternate stream")
        alias = root / "another-name.ini"
        os.link(target, alias)
        check(target, 3, "hard-linked file is rejected")
        alias.unlink()
        check(root, 3, "directory is rejected")
        check(root / "missing.ini", 6, "missing file reports an I/O failure")
        get_security = ctypes.WinDLL("advapi32", use_last_error=True).GetFileSecurityW
        get_security.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPVOID,
                                 wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
        get_security.restype = wintypes.BOOL
        size = wintypes.DWORD()
        get_security(str(target), 0x8, None, 0, ctypes.byref(size))
        error = ctypes.get_last_error()
        expected = 9 if error == 1314 else 0 if error == 122 and size.value else 6
        module = runpy.run_path(str(Path(__file__).with_name("hbbridge.credential.atomic.probe.py")))
        original_security = module["windows_security"](target)
        check(target, expected, "SACL inspection reports the available privilege", "sacl")
        print("SACL inspection result:", "privilege unavailable" if expected == 9 else
              "descriptor readable" if expected == 0 else "inspection unavailable")
        if target.read_bytes() != b"synthetic configuration" or module["windows_security"](target) != original_security:
            raise AssertionError("SACL inspection changed the synthetic file")
        print("PASS SACL inspection leaves file and observed security unchanged")
        print("Credential metadata synthetic checks: 8; failures: 0")


if __name__ == "__main__":
    main()
