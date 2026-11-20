#!/usr/bin/env python3
"""Test stream enumeration with disposable synthetic Windows files."""
import os
from pathlib import Path
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

        def check(path, expected, description):
            path_hex = str(path).encode("utf-8").hex()
            result = subprocess.run([executable, path_hex], capture_output=True, text=True,
                                    check=True, timeout=20)
            if result.stdout.strip() != f"STREAM_STATUS={expected}":
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
        print("Credential stream synthetic checks: 6; failures: 0")


if __name__ == "__main__":
    main()
