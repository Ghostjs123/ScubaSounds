"""A tiny test runner: @test registers a function; run() runs them all (or those matching argv) and reports."""
import sys
import time
import traceback

TESTS = []


def test(fn):
    TESTS.append(fn)
    return fn


def check(condition, message="check failed"):
    if not condition:
        raise AssertionError(message)


def run():
    wanted = sys.argv[1:]
    failed = 0
    started = time.time()
    for fn in TESTS:
        if wanted and not any(w in fn.__name__ for w in wanted):
            continue
        t0 = time.time()
        try:
            fn()
            print("PASS %-48s %6.1fs" % (fn.__name__, time.time() - t0))
        except Exception:
            failed += 1
            print("FAIL %-48s %6.1fs" % (fn.__name__, time.time() - t0))
            traceback.print_exc(limit=6)
    print("%s: %d failed, %.0fs" % ("FAILED" if failed else "OK", failed, time.time() - started))
    sys.exit(1 if failed else 0)
