#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_path="${repo_root}/.build/local-runtime/llama.xcframework"

if [[ ! -d "${runtime_path}" ]]; then
    cat >&2 <<MSG
Missing ${runtime_path}

Run scripts/bootstrap_llama_xcframework.sh first, or use plain xcodegen generate
for the default App Store-safe build without embedded local inference runtime.
MSG
    exit 1
fi

command -v xcodegen >/dev/null

temp_spec="$(mktemp "${TMPDIR:-/tmp}/kairo-local-runtime-project.XXXXXX.yml")"
trap 'rm -f "${temp_spec}"' EXIT

python3 - "$repo_root/project.yml" "$temp_spec" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
text = source.read_text()
needle = """      - package: KairoCore
        product: KairoCore
"""
replacement = needle + """      - framework: .build/local-runtime/llama.xcframework
        embed: true
        codeSign: true
"""
if needle not in text:
    raise SystemExit("Unable to locate KairoApp KairoCore dependency in project.yml")
destination.write_text(text.replace(needle, replacement, 1))
PY

xcodegen generate --spec "${temp_spec}" --project-root "${repo_root}" --project "${repo_root}"
