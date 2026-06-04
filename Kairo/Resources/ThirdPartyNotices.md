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

## Qwen3.5 0.8B GGUF

Kairo's starter model catalog references
`AaryanK/Qwen3.5-0.8B-GGUF` with file `Qwen3.5-0.8B.q4_k_m.gguf`.
The catalog records `licenseName = Apache-2.0` and
`licenseURL = https://www.apache.org/licenses/LICENSE-2.0`.

The model is not bundled with Kairo. Users must explicitly approve the download
preview, including model size, source host, license, purpose boundary, storage
location, backup exclusion policy, and delete flow. Downloaded model files stay
in app-managed local storage and must not be committed to this repository.

## Llama 3.2 1B Instruct GGUF

Kairo's starter catalog also references a Llama 3.2 1B Instruct GGUF artifact
for metadata and download experimentation. It uses the Llama 3.2 Community
License recorded in the model manifest. It is not bundled with Kairo, and its
license must remain visible before any user-triggered download.
