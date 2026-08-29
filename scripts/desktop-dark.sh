#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

mkdir -p .clickable
tmp_config="$(mktemp .clickable/nextsign-desktop-dark.XXXXXX.yaml)"
desktop_env_file=".clickable/nextsign-desktop-env.local"
cleanup() {
    rm -f "$tmp_config"
    rm -f "$desktop_env_file"
}
trap cleanup EXIT

python3 - "$tmp_config" "$desktop_env_file" <<'PY'
import pathlib
import sys

project_config = pathlib.Path("clickable.yaml").read_text(encoding="utf-8")
target = pathlib.Path(sys.argv[1])
desktop_env_file = pathlib.Path(sys.argv[2])

with target.open("w", encoding="utf-8") as handle:
    handle.write(project_config.rstrip())
    handle.write("\n")
    handle.write("env_vars:\n")
    handle.write("  NEXTSIGN_DESKTOP_DARK_MODE: \"1\"\n")

with desktop_env_file.open("w", encoding="utf-8") as handle:
    handle.write("NEXTSIGN_DESKTOP_DARK_MODE=\"1\"\n")
PY

chmod 600 "$desktop_env_file"

~/.local/bin/clickable desktop --arch amd64 --config "$tmp_config"
