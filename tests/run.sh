#!/usr/bin/env bash
# Runs the addon's tests against the mock WoW API, plus a syntax check of every Lua file.
set -euo pipefail

cd "$(dirname "$0")"
lua=${LUA:-$(command -v lua5.1 || command -v luajit || command -v lua)}
luac=${LUAC:-$(command -v luac5.1 || true)}

if [ -n "$luac" ]; then
    find .. -name '*.lua' -not -path '../.release/*' -print0 | xargs -0 "$luac" -p
    rm -f luac.out
fi

for t in test_*.lua; do
    echo "== $t"
    "$lua" "$t"
done
