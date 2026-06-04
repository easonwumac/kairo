#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${repo_root}/.build/local-runtime-src/llama.cpp"
output_dir="${repo_root}/.build/local-runtime"
framework_path="${output_dir}/llama.xcframework"
llama_repo_url="${LLAMA_CPP_REPO_URL:-https://github.com/ggml-org/llama.cpp.git}"
llama_ref="${LLAMA_CPP_REF:-b9430}"

if [[ -d "${framework_path}" ]]; then
    echo "llama.xcframework already exists at ${framework_path}"
    exit 0
fi

command -v git >/dev/null
command -v cmake >/dev/null
command -v xcrun >/dev/null

mkdir -p "$(dirname "${source_dir}")" "${output_dir}"

if [[ ! -d "${source_dir}/.git" ]]; then
    git clone --filter=blob:none "${llama_repo_url}" "${source_dir}"
fi

git -C "${source_dir}" fetch --depth 1 origin "${llama_ref}"
git -C "${source_dir}" checkout --detach FETCH_HEAD

(
    cd "${source_dir}"
    ./build-xcframework.sh
)

if [[ ! -d "${source_dir}/build-apple/llama.xcframework" ]]; then
    echo "Expected llama.xcframework was not produced." >&2
    exit 1
fi

rm -rf "${framework_path}"
cp -R "${source_dir}/build-apple/llama.xcframework" "${framework_path}"

echo "Installed ${framework_path}"
