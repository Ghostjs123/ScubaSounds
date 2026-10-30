"""Runs every test: the addon tests (each prints what it saw; the output must match its snapshot in
tests/addon/expected) and the raid tracking suites in tests/ledger and tests/raids (pass/fail).

    python tests/run_tests.py            run everything
    python tests/run_tests.py --update   rewrite the addon snapshots from the current output
    python tests/run_tests.py --fast     skip the sync simulation (tests/ledger/test_sync.py)
    python tests/run_tests.py cap lava   only the addon tests whose names contain these words (no suites)
"""
import difflib
import glob
import os
import re
import subprocess
import sys
import time

TESTS = os.path.dirname(os.path.abspath(__file__))
ADDON_TESTS = os.path.join(TESTS, "addon")
EXPECTED = os.path.join(ADDON_TESTS, "expected")
SUITES = [os.path.join(TESTS, "ledger", name) for name in ["test_units.py", "test_glue.py", "test_sync.py", "test_raid_night.py"]] + \
         [os.path.join(TESTS, "raids", name) for name in ["test_replay.py", "test_recorder.py", "test_raids_tab.py", "test_sample.py", "test_officer_tab.py",
                                                               "test_liveraid.py"]]
SLOW_SUITES = ["test_sync.py", "test_raid_night.py"]


def run_script(path, deterministic=False):
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    command = [sys.executable, path]
    if deterministic:
        command.insert(1, os.path.join(ADDON_TESTS, "deterministic.py"))
    result = subprocess.run(command, cwd=os.path.dirname(path), env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = result.stdout.decode("utf-8", "replace").replace("\r\n", "\n")
    # Table and function addresses change every run
    return result.returncode, re.sub(r"\b(table|function|userdata|thread):? (0x)?[0-9A-Fa-f]{6,}", r"\1: ADDRESS", output)


def run_addon_tests(update, wanted):
    failed = []
    for path in sorted(glob.glob(os.path.join(ADDON_TESTS, "*_test.py"))):
        name = os.path.basename(path)[:-len("_test.py")]
        if wanted and not any(w in name for w in wanted):
            continue
        code, output = run_script(path, deterministic=True)
        snapshot = os.path.join(EXPECTED, name + ".txt")
        if code != 0:
            failed.append(name)
            print("FAIL %-20s exit code %d\n%s" % (name, code, output))
            continue
        if update:
            os.makedirs(EXPECTED, exist_ok=True)
            with open(snapshot, "w", encoding="utf-8", newline="\n") as f:
                f.write(output)
            print("SAVE %s" % name)
            continue
        if not os.path.exists(snapshot):
            failed.append(name)
            print("FAIL %-20s no snapshot (run with --update)" % name)
            continue
        with open(snapshot, encoding="utf-8") as f:
            expected = f.read()
        if output == expected:
            print("PASS %s" % name)
        else:
            failed.append(name)
            print("FAIL %-20s output changed:" % name)
            sys.stdout.writelines(difflib.unified_diff(expected.splitlines(True), output.splitlines(True),
                                                       "expected", "actual"))
    return failed


def run_suites(fast):
    failed = []
    for path in SUITES:
        suite = os.path.basename(path)
        if fast and suite in SLOW_SUITES:
            continue
        started = time.time()
        code, output = run_script(path)
        print(output, end="")
        if code != 0:
            failed.append(suite)
        print("%s %s (%.0fs)" % ("FAIL" if code else "PASS", suite, time.time() - started))
    return failed


def main():
    args = sys.argv[1:]
    update = "--update" in args
    fast = "--fast" in args
    wanted = [a for a in args if not a.startswith("--")]
    failed = run_addon_tests(update, wanted)
    if not update and not wanted:
        failed += run_suites(fast)
    print("\n%s: %d failed%s" % ("FAILED" if failed else "OK", len(failed),
                                 (" (" + ", ".join(failed) + ")") if failed else ""))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
