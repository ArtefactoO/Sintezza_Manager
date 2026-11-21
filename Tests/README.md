# Offline tests

From the workspace root, run the manager tests with Python 3.12 and Lupa 2.6. Use the path to your bundled Python if it is absent from PATH.

```powershell
python -B Sintezza_Manager/Tests/run.py --runtime .execute-verification/.perf-verification-20261117/runtime
```

The runner compiles every addon's Lua file with Lua 5.1, then runs the manager against the sibling Sintezza Perf frame mock. It covers the default All filter, character-scoped writes, immediate checkbox updates and pending transitions, dependencies, collapse persistence and search, group changes, manual profile loads and saves, the profile tabs, and the game menu. It prints PASS for Russian and English with and without Theme, and for the English fallback. Client taint, controller operation, and in-game appearance require a client check.
