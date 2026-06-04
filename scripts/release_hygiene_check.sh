#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/release_hygiene_check.sh [--skip-swift-test] [--skip-xcodegen] [--require-ci]

Runs Kairo release hygiene checks:
  - swift test
  - xcodegen generate when installed
  - git diff --check
  - App Review boundary scan
  - Share Extension action-free boundary scan
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
echo "== App Review boundary scan =="
python3 - <<'PY'
import plistlib
import sys
from pathlib import Path

root = Path.cwd()

def load_plist(relative_path):
    with (root / relative_path).open("rb") as file:
        return plistlib.load(file)

failures = []

privacy = load_plist("Kairo/Resources/PrivacyInfo.xcprivacy")
if privacy.get("NSPrivacyTracking") is not False:
    failures.append("PrivacyInfo.xcprivacy must keep NSPrivacyTracking=false for the current no-tracking beta claim.")
if privacy.get("NSPrivacyCollectedDataTypes") != []:
    failures.append("PrivacyInfo.xcprivacy must keep NSPrivacyCollectedDataTypes empty unless privacy labels are updated.")
if privacy.get("NSPrivacyTrackingDomains") != []:
    failures.append("PrivacyInfo.xcprivacy must keep NSPrivacyTrackingDomains empty unless tracking is intentionally added.")

app_info = load_plist("Config/KairoApp-Info.plist")
deferred_purpose_keys = [
    "NSHomeKitUsageDescription",
    "NSLocationAlwaysAndWhenInUseUsageDescription",
    "NSLocationWhenInUseUsageDescription",
    "NSPhotoLibraryAddUsageDescription",
    "NSPhotoLibraryUsageDescription",
]
for key in deferred_purpose_keys:
    if key in app_info:
        failures.append(f"{key} must stay out of the beta app plist until that public API path ships.")

required_purpose_keys = [
    "NSCalendarsFullAccessUsageDescription",
    "NSContactsUsageDescription",
    "NSRemindersFullAccessUsageDescription",
    "NSUserNotificationsUsageDescription",
]
for key in required_purpose_keys:
    value = app_info.get(key)
    if not isinstance(value, str) or not value.strip():
        failures.append(f"{key} is required for the currently shipped confirmation-based capability.")

allowed_entitlement_keys = {"com.apple.security.application-groups"}
for relative_path in ["Config/KairoApp.entitlements", "Config/KairoShareExtension.entitlements"]:
    entitlements = load_plist(relative_path)
    unexpected = sorted(set(entitlements) - allowed_entitlement_keys)
    if unexpected:
        failures.append(f"{relative_path} contains unexpected beta entitlement keys: {', '.join(unexpected)}")
    app_groups = entitlements.get("com.apple.security.application-groups")
    if app_groups != ["group.app.kairo.shared"]:
        failures.append(f"{relative_path} must use only the shared Kairo App Group entitlement.")

project = (root / "project.yml").read_text(encoding="utf-8")
deferred_target_names = [
    "Keyboard",
    "Widget",
    "CarPlay",
    "CarMode",
    "HomeKitExtension",
]
for target_name in deferred_target_names:
    if f"  {target_name}:" in project or f"  Kairo{target_name}:" in project:
        failures.append(f"project.yml must not add deferred beta target {target_name}.")

if failures:
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    sys.exit(1)

print("App Review boundary scan passed.")

PY

echo
echo "== Share Extension action-free boundary scan =="
python3 - <<'PY'
import re
import sys
from pathlib import Path

root = Path.cwd()
extension_root = root / "Kairo/Extensions/ShareExtension"
forbidden_patterns = [
    r"\bAgentCore\b",
    r"\bAIProvider\b",
    r"\bOpenAIProvider\b",
    r"\bActionExecutor\b",
    r"\bSandboxActionExecutor\b",
    r"\bLocalModel[A-Za-z0-9_]*\b",
    r"\bEventKit\b",
    r"\bUserNotifications\b",
    r"\bContacts\b",
    r"\bCNContact[A-Za-z0-9_]*\b",
    r"\bEKEvent[A-Za-z0-9_]*\b",
    r"\bEKReminder\b",
    r"\bUNUserNotification[A-Za-z0-9_]*\b",
]
combined = re.compile("|".join(forbidden_patterns))
failures = []

for source in sorted(extension_root.rglob("*.swift")):
    text = source.read_text(encoding="utf-8")
    for line_number, line in enumerate(text.splitlines(), start=1):
        if combined.search(line):
            relative = source.relative_to(root)
            failures.append(f"{relative}:{line_number}: Share Extension must stay queue-only and action/model-free: {line.strip()}")

if failures:
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    sys.exit(1)

print("Share Extension action-free boundary scan passed.")

PY

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
