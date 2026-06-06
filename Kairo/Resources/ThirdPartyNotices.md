# Third-Party Notices

Kairo does not bundle model weights, GGUF files, tokenizers, or downloaded model
caches in the app binary or source repository. Local model downloads are
user-triggered and use the license metadata shown in Settings before download
confirmation.

## llama.cpp

Kairo can embed a locally built `llama.xcframework` for GGUF inference. The
runtime is built from `ggml-org/llama.cpp`, which is licensed under the MIT
License.

MIT License

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Local Model Catalog Entries

Kairo's starter model catalog references Apache-2.0 GGUF artifacts, including
`google/gemma-4-E2B-it-qat-q4_0-gguf`,
`google/gemma-4-E4B-it-qat-q4_0-gguf`,
`Qwen/Qwen2.5-0.5B-Instruct-GGUF`,
`Qwen/Qwen2.5-1.5B-Instruct-GGUF`, and
`ggml-org/Qwen2.5-VL-3B-Instruct-GGUF`.
The catalog records `licenseName = Apache-2.0` and
`licenseURL = https://www.apache.org/licenses/LICENSE-2.0`.

The models are not bundled with Kairo. Users must explicitly approve the download
preview, including model size, source host, license, purpose boundary, storage
location, backup exclusion policy, and delete flow. Downloaded model files stay
in app-managed local storage and must not be committed to this repository.
