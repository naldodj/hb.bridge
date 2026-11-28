#!/usr/bin/env python3
"""Probe local file-replacement primitives using only synthetic data.

This is not the credential editor or a production atomic-write implementation.
"""

import errno
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

if os.name == "nt":
    import ctypes
    import msvcrt
    from ctypes import wintypes
else:
    import fcntl


def acquire_lock(handle):
    handle.seek(0)
    try:
        if os.name == "nt":
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as error:
        if error.errno in (errno.EACCES, errno.EAGAIN, errno.EDEADLK):
            return False
        raise
    return True


def release_lock(handle):
    handle.seek(0)
    if os.name == "nt":
        msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
    else:
        fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def try_lock(path):
    with open(path, "r+b", buffering=0) as handle:
        if not acquire_lock(handle):
            return 0
        release_lock(handle)
        return 1


def windows_security(path):
    advapi = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    get_security = advapi.GetFileSecurityW
    get_security.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPVOID,
                             wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    get_security.restype = wintypes.BOOL
    convert = advapi.ConvertSecurityDescriptorToStringSecurityDescriptorW
    convert.argtypes = [wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD,
                        ctypes.POINTER(wintypes.LPWSTR), ctypes.POINTER(wintypes.DWORD)]
    convert.restype = wintypes.BOOL
    kernel.LocalFree.argtypes = [wintypes.HLOCAL]
    kernel.LocalFree.restype = wintypes.HLOCAL
    information = 0x00000001 | 0x00000002 | 0x00000004
    size = wintypes.DWORD()
    get_security(str(path), information, None, 0, ctypes.byref(size))
    if not size.value:
        raise ctypes.WinError(ctypes.get_last_error())
    descriptor = ctypes.create_string_buffer(size.value)
    if not get_security(str(path), information, descriptor, size, ctypes.byref(size)):
        raise ctypes.WinError(ctypes.get_last_error())
    result = wintypes.LPWSTR()
    if not convert(descriptor, 1, information, ctypes.byref(result), None):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return result.value
    finally:
        kernel.LocalFree(result)


def windows_apply_security(path, sddl, protect=False):
    advapi = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    convert = advapi.ConvertStringSecurityDescriptorToSecurityDescriptorW
    convert.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, ctypes.POINTER(wintypes.LPVOID),
                        ctypes.POINTER(wintypes.DWORD)]
    convert.restype = wintypes.BOOL
    set_security = advapi.SetFileSecurityW
    set_security.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPVOID]
    set_security.restype = wintypes.BOOL
    kernel.LocalFree.argtypes = [wintypes.HLOCAL]
    kernel.LocalFree.restype = wintypes.HLOCAL
    descriptor = wintypes.LPVOID()
    if not convert(sddl, 1, ctypes.byref(descriptor), None):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        information = 0x00000001 | 0x00000002 | 0x00000004
        if protect:
            information |= 0x80000000
        if not set_security(str(path), information, descriptor):
            raise ctypes.WinError(ctypes.get_last_error())
    finally:
        kernel.LocalFree(descriptor)


def windows_check_sacl_access(path):
    advapi = ctypes.WinDLL("advapi32", use_last_error=True)
    get_security = advapi.GetFileSecurityW
    get_security.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPVOID,
                             wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    get_security.restype = wintypes.BOOL
    size = wintypes.DWORD()
    if not get_security(str(path), 0x00000008, None, 0, ctypes.byref(size)):
        error = ctypes.get_last_error()
        if error != 122 or not size.value:
            print("OBSERVED: SACL unavailable; Windows error", error)
            return
    descriptor = ctypes.create_string_buffer(size.value)
    if not get_security(str(path), 0x00000008, descriptor, size, ctypes.byref(size)):
        print("OBSERVED: SACL unavailable; Windows error", ctypes.get_last_error())
        return
    print("OBSERVED: SACL could be read on this synthetic fixture")


def open_reader(path):
    if os.name != "nt":
        return os.open(path, os.O_RDONLY)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    create_file = kernel.CreateFileW
    create_file.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
                            wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    create_file.restype = wintypes.HANDLE
    handle = create_file(str(path), 0x80000000, 0x1 | 0x2 | 0x4, None, 3, 0x80, None)
    if handle == wintypes.HANDLE(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    return handle


def read_and_close_reader(handle, size):
    if os.name != "nt":
        try:
            return os.read(handle, size)
        finally:
            os.close(handle)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.ReadFile.argtypes = [wintypes.HANDLE, wintypes.LPVOID, wintypes.DWORD,
                                ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
    kernel.ReadFile.restype = wintypes.BOOL
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.CloseHandle.restype = wintypes.BOOL
    data = ctypes.create_string_buffer(size)
    read = wintypes.DWORD()
    try:
        if not kernel.ReadFile(handle, data, size, ctypes.byref(read), None):
            raise ctypes.WinError(ctypes.get_last_error())
        return data.raw[:read.value]
    finally:
        kernel.CloseHandle(handle)


def replace_file(target, staged, use_move=False, use_posix=False):
    if os.name != "nt":
        os.replace(staged, target)
        return
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    if use_posix:
        class RenameInfo(ctypes.Structure):
            _fields_ = [("flags", wintypes.DWORD), ("root", wintypes.HANDLE),
                        ("name_length", wintypes.DWORD), ("name", wintypes.WCHAR * 1)]

        create = kernel.CreateFileW
        create.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID,
                           wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        create.restype = wintypes.HANDLE
        rename = kernel.SetFileInformationByHandle
        rename.argtypes = [wintypes.HANDLE, ctypes.c_int, wintypes.LPVOID, wintypes.DWORD]
        rename.restype = wintypes.BOOL
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel.CloseHandle.restype = wintypes.BOOL
        name = str(target).encode("utf-16-le")
        buffer = ctypes.create_string_buffer(RenameInfo.name.offset + len(name) + ctypes.sizeof(wintypes.WCHAR))
        info = RenameInfo.from_buffer(buffer)
        info.flags = 0x1 | 0x2
        info.root = None
        info.name_length = len(name)
        ctypes.memmove(ctypes.addressof(buffer) + RenameInfo.name.offset, name, len(name))
        handle = create(str(staged), 0x10000, 0x1 | 0x2 | 0x4, None, 3, 0x80, None)
        if handle == wintypes.HANDLE(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            if not rename(handle, 22, buffer, len(buffer)):
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            kernel.CloseHandle(handle)
        return
    if use_move:
        move = kernel.MoveFileExW
        move.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD]
        move.restype = wintypes.BOOL
        if not move(str(staged), str(target), 0x1 | 0x8):
            raise ctypes.WinError(ctypes.get_last_error())
        return
    replace = kernel.ReplaceFileW
    replace.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.LPCWSTR,
                        wintypes.DWORD, wintypes.LPVOID, wintypes.LPVOID]
    replace.restype = wintypes.BOOL
    if not replace(str(target), str(staged), None, 0, None, None):
        raise ctypes.WinError(ctypes.get_last_error())


def main(root, protected=False, use_move=False, no_reader=False, use_posix=False, use_stream=False, check_sacl=False):
    root = Path(root).resolve(strict=True)
    if not root.is_dir():
        raise ValueError("probe root must be an existing directory")
    work = root / ("hbbridge-atomic-probe-" + uuid.uuid4().hex)
    work.mkdir(mode=0o700)
    if work.resolve(strict=True).parent != root:
        raise ValueError("probe directory escaped its requested root")
    target, staged, lock = (work / name for name in ("config.ini", "staged.ini", "config.lock"))
    before = b"[Credential/example]\nPassword=synthetic-old\nOther=keep\n"
    after = b"[Credential/example]\nPassword=synthetic-new\nOther=keep\n"
    try:
        target.write_bytes(before)
        if check_sacl:
            if os.name != "nt":
                raise ValueError("the SACL fixture requires Windows")
            windows_check_sacl_access(target)
        if use_stream:
            if os.name != "nt":
                raise ValueError("the alternate-stream fixture requires Windows")
            Path(str(target) + ":hbbridge-test").write_bytes(b"synthetic-stream")
            if Path(str(target) + ":hbbridge-test").read_bytes() != b"synthetic-stream":
                raise AssertionError("synthetic alternate stream was not written")
        if os.name != "nt":
            target.chmod(0o640)
        original = target.stat()
        security = windows_security(target) if os.name == "nt" else None
        if protected:
            if os.name != "nt":
                raise ValueError("the protected-DACL fixture requires Windows")
            owner = security.partition("D:")[0]
            windows_apply_security(target, owner + "D:P(A;;FA;;;OW)(A;;FA;;;SY)", protect=True)
            security = windows_security(target)
            if not security.partition("D:")[2].startswith("P"):
                raise AssertionError("synthetic target DACL was not protected")
        lock.write_bytes(b"x")
        with open(lock, "r+b", buffering=0) as held:
            if not acquire_lock(held):
                raise AssertionError("could not acquire the synthetic lock")
            child = subprocess.run([sys.executable, __file__, "--try-lock", str(lock)], timeout=15, check=False)
            if child.returncode != 0:
                raise AssertionError("another process acquired the held lock")

            staged.write_bytes(b"synthetic-partial")
            if target.read_bytes() != before:
                raise AssertionError("pre-publication staging modified the original")
            target.write_bytes(before.replace(b"old", b"xxx"))
            if target.read_bytes() == before:
                raise AssertionError("same-length conflicting edit was not detected")
            target.write_bytes(before)

            if os.name == "nt":
                windows_apply_security(staged, security)
                if windows_security(staged) != security:
                    raise AssertionError("staged file did not retain owner and DACL")
            descriptor = os.open(staged, os.O_WRONLY | os.O_TRUNC)
            with os.fdopen(descriptor, "wb") as writer:
                writer.write(after)
                writer.flush()
                os.fsync(writer.fileno())
                if os.name != "nt":
                    os.fchmod(writer.fileno(), original.st_mode & 0o7777)
                    os.fsync(writer.fileno())
            reader = open_reader(target)
            if no_reader:
                if read_and_close_reader(reader, len(before)) != before:
                    raise AssertionError("synthetic pre-replacement reader was inconsistent")
                reader = None
            try:
                replace_file(target, staged, use_move, use_posix)
            except BaseException:
                if reader is not None:
                    read_and_close_reader(reader, len(before))
                raise
            if (reader is not None and read_and_close_reader(reader, len(before)) != before) or target.read_bytes() != after:
                raise AssertionError("open reader or replacement contents were inconsistent")
            current = target.stat()
            if os.name == "nt":
                if use_stream:
                    try:
                        stream_contents = Path(str(target) + ":hbbridge-test").read_bytes()
                    except FileNotFoundError:
                        stream_contents = None
                    print("OBSERVED: alternate data stream after replacement:",
                          "PRESENT" if stream_contents == b"synthetic-stream" else "MISSING OR CHANGED")
                replacement_security = windows_security(target)
                if replacement_security != security:
                    before_owner, _, before_dacl = security.partition("D:")
                    after_owner, _, after_dacl = replacement_security.partition("D:")
                    before_aces = [ace.split(";") for ace in re.findall(r"\(([^)]*)\)", before_dacl)]
                    after_aces = [ace.split(";") for ace in re.findall(r"\(([^)]*)\)", after_dacl)]
                    print(
                        "OBSERVED: replacement changed security metadata: "
                        f"owner_equal={before_owner == after_owner}; dacl_equal={before_dacl == after_dacl}; "
                        f"dacl_flags={before_dacl.partition('(')[0]!r}->{after_dacl.partition('(')[0]!r}; "
                        f"ace_count={before_dacl.count('(')}->{after_dacl.count('(')}; "
                        f"aces_equal={before_aces == after_aces}; "
                        f"flags_equal={[ace[1] for ace in before_aces] == [ace[1] for ace in after_aces]}; "
                        f"rights_equal={[ace[2] for ace in before_aces] == [ace[2] for ace in after_aces]}; "
                        f"trustees_equal={[ace[5] for ace in before_aces] == [ace[5] for ace in after_aces]}"
                    )
                    windows_apply_security(target, security)
                    if windows_security(target) != security:
                        raise AssertionError("could not restore original owner and DACL after replacement")
                    print("OBSERVED: explicitly reapplied security descriptor after replacement")
            else:
                if (current.st_mode & 0o7777, current.st_uid, current.st_gid) != (
                    original.st_mode & 0o7777, original.st_uid, original.st_gid
                ):
                    raise AssertionError("replacement changed POSIX permissions or ownership")
                directory = os.open(work, os.O_RDONLY | os.O_DIRECTORY)
                try:
                    os.fsync(directory)
                finally:
                    os.close(directory)

            # A writer ignoring the sidecar lock can edit after the comparison.
            if target.read_bytes() != after:
                raise AssertionError("synthetic preflight snapshot was unexpected")
            target.write_bytes(after.replace(b"new", b"xxx"))
            staged.write_bytes(before)
            replace_file(target, staged, use_move, use_posix)
            if target.read_bytes() != before:
                raise AssertionError("non-cooperating writer scenario was not reproduced")
            print("OBSERVED: a non-cooperating edit after preflight can be overwritten")
            release_lock(held)
        print("Synthetic replacement probe: 6 checks; failures: 0; production safety: NOT ASSESSED")
    finally:
        if work.resolve(strict=True).parent != root:
            raise RuntimeError("probe cleanup refused an unexpected directory")
        if use_stream:
            stream = Path(str(target) + ":hbbridge-test")
            if stream.exists():
                stream.unlink()
        for path in (staged, target, lock):
            if path.exists():
                path.unlink()
        work.rmdir()


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--try-lock":
        raise SystemExit(try_lock(sys.argv[2]))
    if (len(sys.argv) < 2 or any(option not in ("--protected", "--move", "--no-reader", "--posix", "--stream", "--sacl") for option in sys.argv[2:])
            or ("--move" in sys.argv[2:] and "--posix" in sys.argv[2:])):
        raise SystemExit("Usage: atomic.probe.py <existing-directory> [--protected] [--move|--posix] [--no-reader] [--stream] [--sacl]")
    main(sys.argv[1], "--protected" in sys.argv[2:], "--move" in sys.argv[2:], "--no-reader" in sys.argv[2:],
         "--posix" in sys.argv[2:], "--stream" in sys.argv[2:], "--sacl" in sys.argv[2:])
