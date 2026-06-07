#!/usr/bin/env bash
# Seed a pre-downloaded local model into the simulator app container.
# Run this after 'xcrun simctl install'.

set -euo pipefail

SIM_ID="${KAIRO_SIMULATOR_ID:-438DD00C-7A91-4BD2-AFB2-322B1E3F3D67}"
BUNDLE_ID="${KAIRO_BUNDLE_ID:-app.kairo.ios}"
MODEL_SRC="${KAIRO_MODEL_SRC:-$HOME/.cache/kairo-model-bench/Qwen3.5-0.8B.q4_k_m.gguf}"
MODEL_ID="${KAIRO_MODEL_ID:-qwen2-5-0-5b-instruct-q4-k-m}"
MODEL_VERSION="${KAIRO_MODEL_VERSION:-2026.1.0}"

if [[ ! -f "$MODEL_SRC" ]]; then
    echo "Model not found: $MODEL_SRC" >&2
    echo "Set KAIRO_MODEL_SRC to your .gguf file." >&2
    exit 1
fi

# Find app container
CONTAINER=$(xcrun simctl get_app_container "$SIM_ID" "$BUNDLE_ID" data)
if [[ -z "$CONTAINER" ]]; then
    echo "App container not found. Is the app installed?" >&2
    exit 1
fi

MODELS_DIR="$CONTAINER/Documents/LocalModels"
MODEL_DST="$MODELS_DIR/qwen2-5-0-5b-instruct-q4-k-m.gguf"
REGISTRY_FILE="$MODELS_DIR/install-registry.json"
SETTINGS_FILE="$MODELS_DIR/settings.json"

mkdir -p "$MODELS_DIR"

# Copy model
echo "Copying model ($(du -h "$MODEL_SRC" | cut -f1))..."
cp "$MODEL_SRC" "$MODEL_DST"
echo "  → $MODEL_DST"

# Create install registry
MODEL_SIZE=$(stat -f%z "$MODEL_DST" 2>/dev/null || stat -c%s "$MODEL_DST" 2>/dev/null || echo 0)
cat > "$REGISTRY_FILE" <<EOF
[{
  "modelID": "$MODEL_ID",
  "version": "1.0.0",
  "status": "installed",
  "fileURL": "file://$MODEL_DST",
  "installedSizeBytes": $MODEL_SIZE,
  "sha256": "seeded-for-simulator-testing",
  "installedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "lastVerifiedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}]
EOF

# Create settings with model selected
cat > "$SETTINGS_FILE" <<EOF
{
  "selectedModelID": "$MODEL_ID",
  "routePreference": "localOnly"
}
EOF

echo "Model seeded successfully."
echo "  Model:      $MODEL_DST ($(du -h "$MODEL_DST" | cut -f1))"
echo "  Registry:   $REGISTRY_FILE"
echo "  Settings:   $SETTINGS_FILE"
