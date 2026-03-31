#!/usr/bin/env bash
# download_models.sh
# Downloads all required model files to their correct ComfyUI paths.
# Run on RunPod AFTER install_nodes.sh.
#
# Requirements: huggingface-hub CLI  (pip install huggingface_hub)
# For CivitAI checkpoint you need a free account API key:
#   export CIVITAI_API_KEY=your_key_here
# OR manually download toonyou and place it in models/checkpoints/ yourself.

set -euo pipefail

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"

# ── helpers ──────────────────────────────────────────────────────────────────

hf_download() {
    local repo="$1"
    local filename="$2"
    local dest_dir="$3"
    local basename
    basename="$(basename "$filename")"
    local dest="$dest_dir/$basename"
    if [ -f "$dest" ]; then
        echo "  [skip] $basename already exists"
        return
    fi
    echo "  [hf] $repo / $filename → $dest_dir"
    python3 -c "
from huggingface_hub import hf_hub_download
import shutil, os
path = hf_hub_download(repo_id='$repo', filename='$filename')
os.makedirs('$dest_dir', exist_ok=True)
shutil.copy(path, '$dest')
print('  saved:', '$dest')
"
}

civitai_download() {
    local model_id="$1"
    local version_id="$2"
    local filename="$3"
    local dest_dir="$4"
    local dest="$dest_dir/$filename"
    if [ -f "$dest" ]; then
        echo "  [skip] $filename already exists"
        return
    fi
    if [ -z "${CIVITAI_API_KEY:-}" ]; then
        echo "  [WARN] CIVITAI_API_KEY not set — skipping $filename"
        echo "         Download manually: https://civitai.com/models/$model_id"
        echo "         Place at: $dest"
        return
    fi
    echo "  [civitai] $filename → $dest_dir"
    mkdir -p "$dest_dir"
    curl -fL \
        -H "Authorization: Bearer $CIVITAI_API_KEY" \
        "https://civitai.com/api/download/models/$version_id" \
        -o "$dest"
}

# ── directories ───────────────────────────────────────────────────────────────

mkdir -p \
    "$COMFY_DIR/models/checkpoints" \
    "$COMFY_DIR/models/controlnet" \
    "$COMFY_DIR/models/ipadapter" \
    "$COMFY_DIR/models/clip_vision" \
    "$COMFY_DIR/custom_nodes/ComfyUI-AnimateDiff-Evolved/models"

# ── 1. Base checkpoint: toonyou (CivitAI model 30240, version 78775) ──────────
echo ""
echo "==> Base checkpoint (toonyou)"
civitai_download 30240 78775 "toonyou_beta6.safetensors" \
    "$COMFY_DIR/models/checkpoints"

# ── 2. AnimateDiff motion module ──────────────────────────────────────────────
echo ""
echo "==> AnimateDiff motion module"
hf_download "guoyww/animatediff" "mm_sd_v15_v2.ckpt" \
    "$COMFY_DIR/custom_nodes/ComfyUI-AnimateDiff-Evolved/models"

# ── 3. ControlNet lineart ─────────────────────────────────────────────────────
echo ""
echo "==> ControlNet lineart"
hf_download "lllyasviel/ControlNet-v1-1" "control_v11p_sd15_lineart.pth" \
    "$COMFY_DIR/models/controlnet"
# also download the config yaml
hf_download "lllyasviel/ControlNet-v1-1" "control_v11p_sd15_lineart.yaml" \
    "$COMFY_DIR/models/controlnet"

# ── 4. IP-Adapter models ──────────────────────────────────────────────────────
echo ""
echo "==> IP-Adapter models"
hf_download "h94/IP-Adapter" "models/ip-adapter_sd15.safetensors" \
    "$COMFY_DIR/models/ipadapter"
hf_download "h94/IP-Adapter" "models/ip-adapter-plus_sd15.safetensors" \
    "$COMFY_DIR/models/ipadapter"

# ── 5. CLIP Vision encoder ────────────────────────────────────────────────────
echo ""
echo "==> CLIP Vision encoder"
hf_download "h94/IP-Adapter" "models/image_encoder/model.safetensors" \
    "$COMFY_DIR/models/clip_vision"
# rename to expected filename
CLIP_SRC="$COMFY_DIR/models/clip_vision/model.safetensors"
CLIP_DST="$COMFY_DIR/models/clip_vision/clip_vision_g.safetensors"
if [ -f "$CLIP_SRC" ] && [ ! -f "$CLIP_DST" ]; then
    mv "$CLIP_SRC" "$CLIP_DST"
fi

echo ""
echo "==> All downloads complete."
echo "    Verify with: ls -lh $COMFY_DIR/models/checkpoints/"
echo "                 ls -lh $COMFY_DIR/models/controlnet/"
echo "                 ls -lh $COMFY_DIR/models/ipadapter/"
echo "                 ls -lh $COMFY_DIR/models/clip_vision/"
echo "                 ls -lh $COMFY_DIR/custom_nodes/ComfyUI-AnimateDiff-Evolved/models/"
