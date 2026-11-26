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
        module = runpy.run_path(str(Path(__file__).with_name("hbbridge.credential.atomic.probe.py")))
        original_security = module["windows_security"](target)
        checks = 0

        def check(path, expected, description, mode=None):
            nonlocal checks
            path_hex = str(path).encode("utf-8").hex()
            args = [executable, path_hex] + ([mode] if mode else [])
            result = subprocess.run(args, capture_output=True, text=True,
                                    check=True, timeout=20)
            prefix = {"sacl": "SACL_STATUS", "metadata": "METADATA_STATUS", None: "STREAM_STATUS"}[mode]
            if result.stdout.strip() != f"{prefix}={expected}":
                raise AssertionError(description + ": unexpected status " + repr(result.stdout.strip()))
            checks += 1
            print("PASS " + description)

        check(target, 0, "single unnamed stream and Unicode path")
        stream = Path(str(target) + ":hbbridge-test")
        stream.write_bytes(b"synthetic alternate stream")
        if stream.read_bytes() != b"synthetic alternate stream":
            raise AssertionError("Alternate stream fixture was not written")
        check(target, 3, "alternate stream is rejected")
        check(target, 3, "combined inspection rejects alternate stream", "metadata")
        check(stream, 1, "combined inspection rejects directly named stream", "metadata")
        if stream.read_bytes() != b"synthetic alternate stream":
            raise AssertionError("Inspection altered the named stream")
        stream.unlink()
        check(target, 0, "removed alternate stream")
        alias = root / "another-name.ini"
        os.link(target, alias)
        check(target, 3, "hard-linked file is rejected")
        check(target, 3, "combined inspection rejects hard-linked file", "metadata")
        alias.unlink()
        check(root, 3, "directory is rejected")
        check(root, 3, "combined inspection rejects directory", "metadata")
        check(target.name, 1, "combined inspection rejects relative path", "metadata")
        check(root / "missing.ini", 6, "missing file reports an I/O failure")
        check(root / "missing.ini", 6, "combined inspection reports missing file", "metadata")
        get_security = ctypes.WinDLL("advapi32", use_last_error=True).GetFileSecurityW
        get_security.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPVOID,
                                 wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
        get_security.restype = wintypes.BOOL
        size = wintypes.DWORD()
        get_security(str(target), 0x8, None, 0, ctypes.byref(size))
        error = ctypes.get_last_error()
        expected = 9 if error == 1314 else 0 if error == 122 and size.value else 6
        attributes = target.stat().st_file_attributes
        set_attrs = ctypes.WinDLL("kernel32", use_last_error=True).SetFileAttributesW
        set_attrs.argtypes = [wintypes.LPCWSTR, wintypes.DWORD]
        set_attrs.restype = wintypes.BOOL
        for flag, name in ((0x1, "read-only"), (0x2, "hidden")):
            if not set_attrs(str(target), attributes | flag):
                raise ctypes.WinError(ctypes.get_last_error())
            try:
                check(target, 3, "combined inspection rejects " + name + " file", "metadata")
                if target.stat().st_file_attributes != (attributes | flag):
                    raise AssertionError("Inspection altered the attributes")
            finally:
                if not set_attrs(str(target), attributes):
                    raise ctypes.WinError(ctypes.get_last_error())
        sharing = runpy.run_path(str(Path(__file__).with_name("hbbridge.credential.sharing.test.py")))
        writer, error = sharing["open_file"](target, sharing["WRITE"], sharing["SHARE_ALL"])
        if writer is None:
            raise ctypes.WinError(error)
        try:
            check(target, 5, "combined inspection reports existing writer", "metadata")
        finally:
            sharing["close_file"](writer)
        check(target, expected, "SACL inspection reports the available privilege", "sacl")
        check(target, expected, "combined ordinary file inspection reports available privilege", "metadata")
        reader, error = sharing["open_file"](target, sharing["READ"], sharing["SHARE_ALL"])
        if reader is None:
            raise ctypes.WinError(error)
        try:
            check(target, expected, "combined inspection permits a compatible reader", "metadata")
        finally:
            sharing["close_file"](reader)
        print("SACL inspection result:", "privilege unavailable" if expected == 9 else
              "descriptor readable" if expected == 0 else "inspection unavailable")
        if (target.read_bytes() != b"synthetic configuration" or module["windows_security"](target) != original_security
                or target.stat().st_file_attributes != attributes or list(root.iterdir()) != [target]):
            raise AssertionError("Inspection changed the synthetic file or created an artifact")
        checks += 1
        print("PASS inspection preserves file, observed security and directory contents")
        print(f"Credential metadata synthetic checks: {checks}; failures: 0")


if __name__ == "__main__":
    main()
