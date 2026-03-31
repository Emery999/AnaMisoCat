#!/usr/bin/env bash
# install_nodes.sh
# Run this inside the RunPod terminal ONCE after the pod boots.
# Assumes ComfyUI is already installed at /workspace/ComfyUI (standard RunPod template path).

set -euo pipefail

COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
NODES_DIR="$COMFY_DIR/custom_nodes"

echo "==> Installing custom nodes into $NODES_DIR"

cd "$NODES_DIR"

install_node() {
    local name="$1"
    local url="$2"
    if [ -d "$name" ]; then
        echo "  [skip] $name already exists"
    else
        echo "  [clone] $name"
        git clone --depth 1 "$url" "$name"
    fi
}

install_node "ComfyUI-AnimateDiff-Evolved" \
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"

install_node "ComfyUI_IPAdapter_plus" \
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"

install_node "comfyui_controlnet_aux" \
    "https://github.com/Fannovel16/comfyui_controlnet_aux"

install_node "ComfyUI-VideoHelperSuite" \
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"

echo "==> Installing Python requirements for each node"

for node_dir in \
    "ComfyUI-AnimateDiff-Evolved" \
    "ComfyUI_IPAdapter_plus" \
    "comfyui_controlnet_aux" \
    "ComfyUI-VideoHelperSuite"
do
    req="$NODES_DIR/$node_dir/requirements.txt"
    if [ -f "$req" ]; then
        echo "  [pip] $node_dir"
        pip install -q -r "$req"
    fi
done

echo ""
echo "Done. Restart ComfyUI for nodes to load:"
echo "  cd $COMFY_DIR && python main.py --listen 0.0.0.0"
