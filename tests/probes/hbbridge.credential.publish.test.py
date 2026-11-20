#!/usr/bin/env python3
"""Exercise the Linux publisher with disposable, synthetic files only."""
import fcntl
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


def main():
    if len(sys.argv) != 3 or not sys.platform.startswith("linux"):
        raise SystemExit("Usage: publish.test.py <probe executable> <private existing directory>")
    executable = str(Path(sys.argv[1]).resolve(strict=True))
    root = Path(sys.argv[2]).resolve(strict=True)
    checks = 0
    with tempfile.TemporaryDirectory(prefix="hbbridge-publish-test-", dir=root) as name:
        work = Path(name)
        expected = work / "expected"
        replacement = work / "replacement"
        target = work / "configuration.ini"
        lock = work / "configuration.ini.hbbridge.lock"
        old = b"[fixture]\nvalue=old\n"
        new = b"[fixture]\nvalue=new\n"
        expected.write_bytes(old)
        replacement.write_bytes(new)

        def run(path=target, extra=None):
            env = os.environ.copy()
            if extra:
                env.update(extra)
            result = subprocess.run([executable, str(path), str(expected), str(replacement)],
                                    check=True, capture_output=True, text=True, env=env, timeout=20)
            line = result.stdout.strip()
            if not line.startswith("PUBLISH_STATUS="):
                raise AssertionError("Unexpected probe result")
            return int(line.split("=", 1)[1])

        def check(condition, label):
            nonlocal checks
            checks += 1
            if not condition:
                raise AssertionError(label)
            print("PASS " + label)

        def no_stages():
            return not list(work.glob(".hbbridge-stage-*"))

        def start_paused():
            env = os.environ.copy()
            env["HBBRIDGE_TEST_PUBLISH_PAUSE_BEFORE_RECHECK"] = "1"
            process = subprocess.Popen([executable, str(target), str(expected), str(replacement)],
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise AssertionError("Publisher exited before the staged-file check")
                state = Path(f"/proc/{process.pid}/status").read_text()
                if "State:\tT" in state:
                    return process
                time.sleep(0.02)
            process.kill()
            process.communicate(timeout=5)
            raise AssertionError("Publisher did not reach the staged-file check")

        target.write_bytes(old)
        target.chmod(0o640)
        before = target.stat()
        with target.open("rb") as reader:
            check(run() == 0, "publish")
            check(reader.read() == old and target.read_bytes() == new, "reader snapshot")
        after = target.stat()
        check((before.st_uid, before.st_gid, before.st_mode & 0o7777) ==
              (after.st_uid, after.st_gid, after.st_mode & 0o7777), "owner and mode")
        check(lock.is_file() and no_stages(), "stable lock and stage cleanup")

        target.write_bytes(b"[fixture]\nvalue=ext\n")
        check(run() == 4 and target.read_bytes() != new and no_stages(), "stale snapshot")
        target.write_bytes(old)
        with lock.open("rb+") as held:
            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
            check(run() == 5 and target.read_bytes() == old, "cooperative lock")

        check(run(extra={"HBBRIDGE_TEST_PUBLISH_BEFORE_RENAME": "1"}) == 6 and
              target.read_bytes() == old and no_stages(), "failure before rename")
        check(run(extra={"HBBRIDGE_TEST_PUBLISH_DIRSYNC_FAIL": "1"}) == 8 and
              target.read_bytes() == new and no_stages(), "published but not durable")
        target.write_bytes(old)

        paused = start_paused()
        try:
            target.write_bytes(b"[fixture]\nvalue=ext\n")
            os.kill(paused.pid, signal.SIGCONT)
            out, _ = paused.communicate(timeout=10)
            check(paused.returncode == 0 and out.strip() == "PUBLISH_STATUS=4" and
                  target.read_bytes() != new and no_stages(), "change after staging is rejected")
        finally:
            if paused.poll() is None:
                paused.kill()
                paused.communicate(timeout=5)
        target.write_bytes(old)

        paused = start_paused()
        try:
            paused.kill()
            paused.communicate(timeout=10)
            stages = list(work.glob(".hbbridge-stage-*"))
            check(target.read_bytes() == old and len(stages) == 1 and
                  (stages[0].stat().st_mode & 0o7777) == (target.stat().st_mode & 0o7777),
                  "interrupted staging leaves original and restricted orphan")
            stages[0].unlink()
        finally:
            if paused.poll() is None:
                paused.kill()
                paused.communicate(timeout=5)

        linked = work / "hardlink"
        os.link(target, linked)
        check(run() == 3 and target.read_bytes() == old, "hard link rejected")
        linked.unlink()
        target.unlink()
        target.symlink_to(expected)
        check(run() == 3 and target.is_symlink() and expected.read_bytes() == old, "symbolic link rejected")
        target.unlink()
        target.write_bytes(old)
        target.chmod(0o660)
        check(run() == 3 and target.read_bytes() == old, "writable target rejected")
        target.chmod(0o640)
        try:
            os.setxattr(target, "user.hbbridge.test", b"synthetic")
        except OSError:
            print("SKIP extended attributes unsupported")
        else:
            check(run() == 3 and target.read_bytes() == old, "extended attributes rejected")
            os.removexattr(target, "user.hbbridge.test")

        bad_dir = work / "untrusted"
        bad_dir.mkdir(mode=0o770)
        bad_dir.chmod(0o770)
        bad_target = bad_dir / "configuration.ini"
        bad_target.write_bytes(old)
        check(run(bad_target) == 3 and bad_target.read_bytes() == old, "writable directory rejected")

        lock.unlink()
        lock.symlink_to(expected)
        check(run() == 3 and expected.read_bytes() == old and target.read_bytes() == old,
              "symbolic lock rejected")
        lock.unlink()

        unicode_target = work / "configuração.ini"
        unicode_target.write_bytes(old)
        check(run(unicode_target) == 0 and unicode_target.read_bytes() == new, "UTF-8 file name")

        target.write_bytes(old)
        processes = [subprocess.Popen([executable, str(target), str(expected), str(replacement)],
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                     for _ in range(2)]
        outcomes = []
        for process in processes:
            out, err = process.communicate(timeout=20)
            if process.returncode or not out.strip().startswith("PUBLISH_STATUS="):
                raise AssertionError("Concurrent probe failed: " + err)
            outcomes.append(int(out.strip().split("=", 1)[1]))
        check(outcomes.count(0) == 1 and set(outcomes) <= {0, 4, 5} and
              target.read_bytes() == new and no_stages(), "concurrent cooperative publishers")
        print("Credential publication synthetic checks:", checks, "; failures: 0")


if __name__ == "__main__":
    main()
