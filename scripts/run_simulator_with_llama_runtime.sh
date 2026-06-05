#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_path="${repo_root}/Kairo.xcodeproj"
scheme="${KAIRO_SCHEME:-KairoApp}"
simulator_id="${KAIRO_SIMULATOR_ID:-438DD00C-7A91-4BD2-AFB2-322B1E3F3D67}"
bundle_id="${KAIRO_BUNDLE_ID:-app.kairo.ios}"
derived_data_path="${repo_root}/.build/xcode-sim-llama"
framework_path="${repo_root}/.build/local-runtime/llama.xcframework"
simulator_framework_path="${framework_path}/ios-arm64_x86_64-simulator/llama.framework"
launch_args="${KAIRO_LAUNCH_ARGS:-}"

if [[ ! -d "${simulator_framework_path}" ]]; then
    cat >&2 <<EOF
Missing simulator llama.framework at:
  ${simulator_framework_path}

Build it first with:
  scripts/bootstrap_llama_xcframework.sh
EOF
    exit 1
fi

xcodebuild \
    -project "${project_path}" \
    -scheme "${scheme}" \
    -destination "id=${simulator_id}" \
    -derivedDataPath "${derived_data_path}" \
    "FRAMEWORK_SEARCH_PATHS=\$(SRCROOT)/.build/local-runtime/llama.xcframework/ios-arm64_x86_64-simulator \$(inherited)" \
    "OTHER_LDFLAGS=\$(inherited) -framework llama" \
    build

app_path="${derived_data_path}/Build/Products/Debug-iphonesimulator/${scheme}.app"
if [[ ! -d "${app_path}" ]]; then
    echo "Expected built app was not found at ${app_path}" >&2
    exit 1
fi

mkdir -p "${app_path}/Frameworks"
rm -rf "${app_path}/Frameworks/llama.framework"
cp -R "${simulator_framework_path}" "${app_path}/Frameworks/llama.framework"

/usr/bin/codesign --force --sign - --timestamp=none "${app_path}/Frameworks/llama.framework"
/usr/bin/codesign --force --sign - --timestamp=none "${app_path}/${scheme}.debug.dylib"
/usr/bin/codesign --force --sign - --timestamp=none "${app_path}"

xcrun simctl boot "${simulator_id}" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "${simulator_id}"
xcrun simctl install "${simulator_id}" "${app_path}"
if [[ -n "${launch_args}" ]]; then
    # shellcheck disable=SC2206
    parsed_launch_args=(${launch_args})
    xcrun simctl launch "${simulator_id}" "${bundle_id}" "${parsed_launch_args[@]}"
else
    xcrun simctl launch "${simulator_id}" "${bundle_id}"
fi
