#!/usr/bin/env python3
"""Test stream enumeration with disposable synthetic Windows files."""
import os
import ctypes
from ctypes import wintypes
from pathlib import Path
import runpy
import re
import subprocess
import sys
import tempfile


def main():
    if os.name != "nt" or (len(sys.argv) != 2 and
                           not (len(sys.argv) == 3 and sys.argv[2] in ("--require-audit", "--require-audit-replace"))):
        raise SystemExit("Usage: stream.test.py <probe executable> [--require-audit|--require-audit-replace] (Windows only)")
    executable = str(Path(sys.argv[1]).resolve(strict=True))
    with tempfile.TemporaryDirectory(prefix="hbbridge-stream-test-") as directory:
        root = Path(directory)
        target = root / "configuração.ini"
        target.write_bytes(b"synthetic configuration")
        module = runpy.run_path(str(Path(__file__).with_name("hbbridge.credential.atomic.probe.py")))
        original_security = module["windows_security"](target)
        checks = 0

        def check(path, expected, description, mode=None, refusal_stages=None):
            nonlocal checks
            path_hex = str(path).encode("utf-8").hex()
            args = [executable, path_hex] + ([mode] if mode else [])
            result = subprocess.run(args, capture_output=True, text=True,
                                    check=True, timeout=20)
            prefix = {"sacl": "SACL_STATUS", "metadata": "METADATA_STATUS", "audit-fixture": "AUDIT_STATUS",
                      "audit-replace-fixture": "AUDIT_STATUS", None: "STREAM_STATUS"}[mode]
            accepted = expected if isinstance(expected, tuple) else (expected,)
            if result.stdout.strip() not in {f"{prefix}={code}" for code in accepted}:
                detail = result.stderr.strip()
                if mode not in ("audit-fixture", "audit-replace-fixture") or not re.fullmatch(r"AUDIT_STAGE=[A-Za-z0-9.]+ WIN32=[0-9]+", detail):
                    detail = ""
                raise AssertionError(description + ": unexpected status " + repr(result.stdout.strip()) + " " + detail)
            observed = int(result.stdout.strip().split("=")[1])
            if refusal_stages and result.stderr.strip() not in refusal_stages[observed]:
                raise AssertionError(description + ": unexpected refusal stage")
            checks += 1
            print("PASS " + description)
            return observed

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
        if len(sys.argv) == 3:
            audit = root / "hbbridge-audit-fixture.ini"
            check(audit, 0, "protected audit ACE round trip", "audit-fixture")
            if audit.read_bytes() != b"synthetic audit fixture":
                raise AssertionError("Combined inspection changed the audited fixture")
            check(audit, 6, "audit fixture refuses to replace an existing file", "audit-fixture")
            if audit.read_bytes() != b"synthetic audit fixture":
                raise AssertionError("Existing audited fixture changed")
        replacement = root / "hbbridge-audit-replace.ini"
        stage = root / (replacement.name + ".stage")
        mode = "audit-replace-fixture"
        marker = b"existing synthetic file"
        replacement.write_bytes(marker)
        existing_security = module["windows_security"](replacement)
        missing_privilege = {9: {"AUDIT_STAGE=token.enablePrivilege WIN32=1300"}}
        occupied_target = {6: {"AUDIT_STAGE=fixture.CreateFileW WIN32=80", "AUDIT_STAGE=fixture.CreateFileW WIN32=183"}}
        status = check(replacement, (6, 9), "replacement fixture refuses an existing target", mode,
                       {**missing_privilege, **occupied_target})
        if replacement.read_bytes() != marker or module["windows_security"](replacement) != existing_security or stage.exists():
            raise AssertionError("Refusal changed the existing target or created a stage")
        replacement.unlink()
        previous_files = set(root.iterdir())
        if status == 9:
            check(replacement, 9, "missing audit privilege refuses before fixture creation", mode, missing_privilege)
            if set(root.iterdir()) != previous_files:
                raise AssertionError("Privilege refusal created a file")
        if sys.argv[-1] == "--require-audit-replace":
            stage.write_bytes(marker)
            check(replacement, 6, "existing stage is preserved and publication refused", mode,
                  {6: {"AUDIT_STAGE=replace.createStage WIN32=80", "AUDIT_STAGE=replace.createStage WIN32=183"}})
            if (stage.read_bytes() != marker or replacement.read_bytes() != b"[fixture]\r\nrevision=1\r\n"
                    or set(root.iterdir()) != previous_files | {stage, replacement}):
                raise AssertionError("Stage collision changed the synthetic original or the preexisting stage")
            stage.unlink()
            replacement.unlink()
            check(replacement, 0, "replacement preserves full observed descriptor and protected audit ACE", mode)
            if (replacement.read_bytes() != b"[fixture]\r\nrevision=2\r\n"
                    or set(root.iterdir()) != previous_files | {replacement}):
                raise AssertionError("Unexpected published bytes or staging artifact")
        print(f"Credential metadata synthetic checks: {checks}; failures: 0")


if __name__ == "__main__":
    main()
