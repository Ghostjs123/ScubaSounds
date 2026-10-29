# Tests

The addon's Lua runs in Lua 5.1 (WoW's version) through [lupa](https://pypi.org/project/lupa/), with the game faked
around it. Nothing here ships: `.pkgmeta` leaves `tests` out of releases.

```
pip install -r tests/requirements.txt
python tests/run_tests.py            # everything
python tests/run_tests.py --fast     # without the long sync simulation
python tests/run_tests.py lava cap   # only the addon tests whose names contain these words
python tests/run_tests.py --update   # rewrite the addon snapshots
```

The Tests GitHub workflow runs `python tests/run_tests.py` on every push.

## tests/addon

Each `*_test.py` loads the addon's files, drives a scenario and prints what happened. `run_tests.py` compares that
output with `expected/<name>.txt`. When a change alters an output on purpose, run `--update` and check the
snapshot diff before committing it.

`deterministic.py` runs each test so its output is the same every time, on every platform: every Lua runtime is
Lua 5.1, `math.random` is a fixed-seed generator, and the runner masks table addresses. A test can also be run on
its own (`python tests/addon/lava_test.py`). That uses lupa's default Lua and a random seed, and it can take the
addon folder as its first argument.

## tests/ledger

The raid tracking sync (`RaidTracking/Ledger`), as pass/fail suites:

- `test_units.py`: LedgerStore (validation, ordering, digests) and LedgerComms (splitting, compression, garbage).
- `test_glue.py`: Ledger.lua with the real ChatThrottleLib and the addon's retrying sender, with lockdown,
  prefixes, channels and guild switches.
- `test_sync.py`: guilds of simulated clients on a lossy, throttled network (`ledger_env.py`). Covers logging on and
  off, partitions, lockdowns, late and corrupt messages. It's simulated time, so hours of guild activity run in about 15 seconds.

Run a few tests by name: `python tests/ledger/test_sync.py partition lockdown`.
