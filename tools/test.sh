#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/godot/godot}"
"$GODOT" --headless --path "$ROOT" --import --quit
"$GODOT" --headless --path "$ROOT" res://tests/test_runner.tscn
