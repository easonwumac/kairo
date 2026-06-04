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
  - catalog publication boundary scan
  - local model runtime boundary scan
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
echo "== catalog publication boundary scan =="
python3 - <<'PY'
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

root = Path.cwd()
failures = []

def load_json(relative_path):
    with (root / relative_path).open("r", encoding="utf-8") as file:
        return json.load(file)

skills_catalog = load_json("Website/skills/skills.json")
models_catalog = load_json("Website/models/models.json")

if skills_catalog.get("catalogSignatureStatus") != "referenceUnsigned":
    failures.append("Website/skills/skills.json must remain referenceUnsigned in the app repo; publish production signed catalogs from kairo-skills.")
if models_catalog.get("catalogSignatureStatus") != "referenceUnsigned":
    failures.append("Website/models/models.json must remain referenceUnsigned in the app repo; publish production signed catalogs from kairo-models.")

if models_catalog.get("signature") != "unsigned-reference-catalog":
    failures.append("Website/models/models.json must not contain production signature material in this app repo seed.")
if models_catalog.get("signingKeyID") != "kairo-models-reference":
    failures.append("Website/models/models.json must keep the reference signingKeyID until standalone production publication.")

for model in models_catalog.get("models", []):
    model_id = model.get("id", "<missing>")
    parsed = urlparse(model.get("downloadURL", ""))
    if parsed.scheme != "https" or not parsed.netloc:
        failures.append(f"Model {model_id} must use an external HTTPS downloadURL, not an inline or bundled artifact.")
    for forbidden_key in ["weights", "modelWeights", "tokenizer", "tokenizerJSON", "blob", "data"]:
        if forbidden_key in model:
            failures.append(f"Model {model_id} must not inline {forbidden_key} in the app repo catalog seed.")
    if not model.get("sha256"):
        failures.append(f"Model {model_id} must keep sha256 metadata for verified user-triggered downloads.")

for relative_path in sorted((root / "Website/skills/manifests").glob("*.json")):
    manifest = json.loads(relative_path.read_text(encoding="utf-8"))
    signature = manifest.get("signature", {})
    if signature.get("value") != "static-demo-signature":
        failures.append(f"{relative_path.relative_to(root)} must not contain production signature material in this app repo seed.")
    if signature.get("keyID") != "kairo-marketplace-2026":
        failures.append(f"{relative_path.relative_to(root)} must keep the reference marketplace key ID until standalone production publication.")

if failures:
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    sys.exit(1)

print("Catalog publication boundary scan passed.")

PY

echo
echo "== local model runtime boundary scan =="
python3 - <<'PY'
import re
import sys
from pathlib import Path

root = Path.cwd()
failures = []

environment_source = (root / "Kairo/Services/KairoEnvironment.swift").read_text(encoding="utf-8")
reply_check_source = (root / "Kairo/Services/LocalModelReplyCheck.swift").read_text(encoding="utf-8")
benchmark_source = (root / "Kairo/Services/LocalModelBenchmarking.swift").read_text(encoding="utf-8")

if "#if os(macOS)" not in environment_source or "#else" not in environment_source:
    failures.append("KairoEnvironment.live must keep macOS/dev local-model runtime wiring separated from iOS production wiring.")

macos_block_match = re.search(r"#if os\(macOS\)(.*?)#else", environment_source, flags=re.S)
ios_block_match = re.search(r"#else(.*?)#endif\s+let credentialStore", environment_source, flags=re.S)

if not macos_block_match:
    failures.append("KairoEnvironment.live is missing the macOS/dev local-model runtime block.")
else:
    macos_block = macos_block_match.group(1)
    if "LocalModelExternalCommandRuntime" not in macos_block:
        failures.append("macOS/dev local-model block should be the only live external command runtime path.")

if not ios_block_match:
    failures.append("KairoEnvironment.live is missing the non-macOS unavailable local-model runtime block.")
else:
    ios_block = ios_block_match.group(1)
    forbidden_ios_runtime_tokens = [
        "LocalModelExternalCommandRuntime",
        "ProcessLocalModelCommandRunner",
        "DeterministicLocalModelReplyCheckRuntime",
        "DeterministicLocalModelBenchmarkEngine",
        "runtime:",
        "engine:",
    ]
    for token in forbidden_ios_runtime_tokens:
        if token in ios_block:
            failures.append(f"non-macOS live local-model path must stay unavailable and must not wire {token}.")

if "runtime: any LocalModelReplyCheckRuntime = UnavailableLocalModelReplyCheckRuntime()" not in reply_check_source:
    failures.append("LocalModelReplyCheckService default runtime must remain UnavailableLocalModelReplyCheckRuntime.")

if "engine: any LocalModelBenchmarkEngine = UnavailableLocalModelBenchmarkEngine()" not in benchmark_source:
    failures.append("LocalModelBenchmarkService default engine must remain UnavailableLocalModelBenchmarkEngine.")

if failures:
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    sys.exit(1)

print("Local model runtime boundary scan passed.")

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
