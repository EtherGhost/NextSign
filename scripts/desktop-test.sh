#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

mkdir -p .clickable

dark_mode=0
if [[ "${1:-}" == "--dark" ]]; then
    dark_mode=1
fi

env_source=""
for candidate in ".env.test.local" "../NextNews/.env.test.local" "../NextNotes/.env.test.local" "../NextTasks/.env.test.local" "../NextDeck/.env.test.local"; do
    if [[ -f "$candidate" ]]; then
        env_source="$candidate"
        break
    fi
done

if [[ -z "$env_source" ]]; then
    echo "Missing test credentials. Create .env.test.local or keep an existing sibling app's test env file available." >&2
    exit 1
fi

tmp_config="$(mktemp .clickable/nextsign-desktop-test.XXXXXX.yaml)"
desktop_env_file=".clickable/nextsign-desktop-env.local"
cleanup() {
    rm -f "$tmp_config"
    rm -f "$desktop_env_file"
}
trap cleanup EXIT

python3 - "$env_source" "$tmp_config" "$desktop_env_file" "$dark_mode" <<'INNERPY'
import pathlib
import sys

env_path = pathlib.Path(sys.argv[1])
config_path = pathlib.Path(sys.argv[2])
desktop_env_path = pathlib.Path(sys.argv[3])
dark_mode = sys.argv[4] == "1"
project_config = pathlib.Path("clickable.yaml").read_text(encoding="utf-8")

def parse_env(path):
    values = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values

values = parse_env(env_path)

def first(*keys):
    for key in keys:
        value = values.get(key, "").strip()
        if value:
            return value
    return ""

mapped = {
    "NEXTSIGN_DESKTOP_TEST_AUTH": "1",
    "NEXTSIGN_TEST_SERVER": first("NEXTSIGN_TEST_SERVER", "NEXTCLOUD_TEST_SERVER", "NEXTNEWS_TEST_SERVER", "NEXTNOTES_TEST_SERVER", "NEXTTASKS_TEST_SERVER", "NEXTDECK_TEST_SERVER"),
    "NEXTSIGN_TEST_USERNAME": first("NEXTSIGN_TEST_USERNAME", "NEXTCLOUD_TEST_USERNAME", "NEXTNEWS_TEST_USERNAME", "NEXTNOTES_TEST_USERNAME", "NEXTTASKS_TEST_USERNAME", "NEXTDECK_TEST_USERNAME"),
    "NEXTSIGN_TEST_APP_PASSWORD": first("NEXTSIGN_TEST_APP_PASSWORD", "NEXTCLOUD_TEST_APP_PASSWORD", "NEXTNEWS_TEST_APP_PASSWORD", "NEXTNOTES_TEST_APP_PASSWORD", "NEXTTASKS_TEST_APP_PASSWORD", "NEXTDECK_TEST_APP_PASSWORD"),
}
if dark_mode:
    mapped["NEXTSIGN_DESKTOP_DARK_MODE"] = "1"

missing = [key for key in ["NEXTSIGN_TEST_SERVER", "NEXTSIGN_TEST_USERNAME", "NEXTSIGN_TEST_APP_PASSWORD"] if not mapped[key]]
if missing:
    raise SystemExit("Missing required test env values: " + ", ".join(missing))

with config_path.open("w", encoding="utf-8") as handle:
    handle.write(project_config.rstrip())
    handle.write("\n")
    handle.write("env_vars:\n")
    for key, value in mapped.items():
        handle.write(f"  {key}: {value!r}\n")

with desktop_env_path.open("w", encoding="utf-8") as handle:
    for key, value in mapped.items():
        handle.write(f"{key}={value!r}\n")
INNERPY

chmod 600 "$desktop_env_file"
~/.local/bin/clickable desktop --arch amd64 --config "$tmp_config"
