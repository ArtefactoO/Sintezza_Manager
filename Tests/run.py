import argparse
from pathlib import Path
import sys


parser = argparse.ArgumentParser()
parser.add_argument("--runtime", required=True, type=Path, help="Directory containing Lupa 2.6")
args = parser.parse_args()
sys.path.insert(0, str(args.runtime.resolve()))

from lupa.lua51 import LuaRuntime

addon = Path(__file__).resolve().parents[1]
lua_files = sorted(addon.rglob("*.lua"))
for file in lua_files:
    LuaRuntime().compile(file.read_text(encoding="utf-8"), name=file.name)
print(f"Lua 5.1 syntax: {len(lua_files)} files")

frame_mock = (addon.parent / "Sintezza_Perf/Tests/FrameMock.lua").read_text(encoding="utf-8")
tests = (addon / "Tests/Manager.lua").read_text(encoding="utf-8")
for client, theme in [("enUS", False), ("ruRU", False), ("ruRU", "enUS"), ("enUS", "ruRU"), ("deDE", False)]:
    runtime = LuaRuntime()
    runtime.globals().ADDON_ROOT = addon.as_posix()
    runtime.globals().TEST_LOCALE = client
    runtime.globals().THEME_LOCALE = theme
    runtime.execute(frame_mock)
    runtime.execute(tests)
    print(f"PASS: client={client}, theme={theme or 'off'}")
