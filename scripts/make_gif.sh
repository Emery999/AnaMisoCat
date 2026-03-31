#!/usr/bin/env bash
# make_gif.sh
# Assembles output PNG frames (from ComfyUI) into a looping GIF and MP4.
#
# Usage: ./scripts/make_gif.sh [frames_dir] [output_name]
#   frames_dir   defaults to ./output/frames
#   output_name  defaults to cat_walk_out (produces .gif and .mp4)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAMES_DIR="${1:-$REPO_DIR/output/frames}"
OUT_NAME="${2:-cat_walk_out}"
OUT_DIR="$REPO_DIR/output"

if [ ! -d "$FRAMES_DIR" ]; then
    echo "ERROR: frames dir not found: $FRAMES_DIR"
    echo "       Download output frames from RunPod first:"
    echo "       scp -r <pod-ip>:/workspace/ComfyUI/output/ $REPO_DIR/output/frames/"
    exit 1
fi

FRAME_COUNT=$(ls "$FRAMES_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
if [ "$FRAME_COUNT" -eq 0 ]; then
    echo "ERROR: no PNG files found in $FRAMES_DIR"
    exit 1
fi
echo "==> Found $FRAME_COUNT frames in $FRAMES_DIR"

mkdir -p "$OUT_DIR"

# ── GIF (palette-optimized for quality) ──────────────────────────────────────
echo "==> Building GIF: $OUT_DIR/$OUT_NAME.gif"
ffmpeg -loglevel warning -y \
    -framerate 5 \
    -pattern_type glob -i "$FRAMES_DIR/*.png" \
    -vf "fps=5,split[s0][s1];[s0]palettegen=max_colors=256:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer" \
    "$OUT_DIR/$OUT_NAME.gif"

# ── MP4 (H.264, web-compatible) ───────────────────────────────────────────────
echo "==> Building MP4: $OUT_DIR/$OUT_NAME.mp4"
ffmpeg -loglevel warning -y \
    -framerate 5 \
    -pattern_type glob -i "$FRAMES_DIR/*.png" \
    -vf "fps=5,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 \
    "$OUT_DIR/$OUT_NAME.mp4"

echo ""
echo "Done:"
ls -lh "$OUT_DIR/$OUT_NAME.gif" "$OUT_DIR/$OUT_NAME.mp4"
