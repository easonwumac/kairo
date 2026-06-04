#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release_hygiene_check.sh [--skip-swift-test] [--skip-xcodegen] [--require-ci]

Runs Kairo release hygiene checks:
  - swift test
  - xcodegen generate when installed
  - git diff --check
  - focused secret scan
  - model artifact scan
  - optional GitHub Actions exact-HEAD gate with --require-ci
EOF
}

run_swift_test=1
run_xcodegen=1
require_ci=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-swift-test)
      run_swift_test=0
      shift
      ;;
    --skip-xcodegen)
      run_xcodegen=0
      shift
      ;;
    --require-ci)
      require_ci=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

echo "== Kairo release hygiene =="
echo "Repo: $repo_root"
echo "HEAD: $(git rev-parse HEAD)"

if [[ "$run_swift_test" -eq 1 ]]; then
  echo
  echo "== swift test =="
  swift test
else
  echo
  echo "== swift test =="
  echo "Skipped by --skip-swift-test"
fi

if [[ "$run_xcodegen" -eq 1 ]]; then
  echo
  echo "== xcodegen generate =="
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
  else
    echo "xcodegen not installed"
  fi
else
  echo
  echo "== xcodegen generate =="
  echo "Skipped by --skip-xcodegen"
fi

echo
echo "== git diff --check =="
git diff --check

echo
echo "== focused secret scan =="
secret_matches="$(mktemp)"
model_matches=""
trap 'rm -f "$secret_matches" "$model_matches"' EXIT
if rg -n --hidden \
  --glob '!/.git/**' \
  --glob '!/.build/**' \
  --glob '!tmp/**' \
  --glob '!Kairo.xcodeproj/**' \
  --glob '!*.xcuserstate' \
  --glob '!*.xcuserdata/**' \
  '(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY|xox[baprs]-[A-Za-z0-9-]{10,}|[A-Za-z0-9._%+-]+:[A-Za-z0-9._%+-]+@)' \
  . >"$secret_matches"; then
  cat "$secret_matches"
  echo "Secret scan found matches; review before committing." >&2
  exit 1
fi
echo "No high-confidence secret matches."

echo
echo "== model artifact scan =="
model_matches="$(mktemp)"
find . \
  \( -path './.git' -o -path './.build' -o -path './tmp' -o -path './Kairo.xcodeproj' \) -prune \
  -o \( -iname '*.gguf' -o -iname '*.safetensors' -o -iname 'tokenizer.json' -o -iname '*.mlmodel' -o -iname '*.mlpackage' -o -iname '*.mobileprovision' -o -iname '*.p12' -o -iname '*.pem' \) \
  -print >"$model_matches"
if [[ -s "$model_matches" ]]; then
  cat "$model_matches"
  echo "Model artifact scan found matches; review before committing." >&2
  exit 1
fi
echo "No model artifacts or generated credential files found."

if [[ "$require_ci" -eq 1 ]]; then
  echo
  echo "== GitHub Actions exact-HEAD gate =="
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh is required for --require-ci." >&2
    exit 1
  fi

  head_sha="$(git rev-parse HEAD)"
  branch="$(git branch --show-current)"
  runs_json="$(gh run list --repo easonwumac/kairo --branch "$branch" --limit 20 --json databaseId,status,conclusion,workflowName,headSha,url)"
  RUNS_JSON="$runs_json" HEAD_SHA="$head_sha" python3 - <<'PY'
import json
import os
import sys

runs = json.loads(os.environ["RUNS_JSON"])
head_sha = os.environ["HEAD_SHA"]
for run in runs:
    if run.get("headSha") == head_sha and run.get("workflowName") == "Swift Tests":
        if run.get("status") == "completed" and run.get("conclusion") == "success":
            print(f"Swift Tests passed for HEAD: {run.get('url')}")
            sys.exit(0)
        print(
            "Swift Tests run for HEAD is not successful: "
            f"status={run.get('status')} conclusion={run.get('conclusion')} url={run.get('url')}",
            file=sys.stderr,
        )
        sys.exit(1)
print("No Swift Tests run found for HEAD.", file=sys.stderr)
sys.exit(1)
PY
fi

echo
echo "Release hygiene checks passed."
