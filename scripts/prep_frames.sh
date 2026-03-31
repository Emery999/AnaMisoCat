#!/usr/bin/env bash
# prep_frames.sh
# Extracts wireframe GIF frames, loops to reach AnimateDiff minimum (16),
# and writes numbered PNGs to frames/.
#
# Run locally before uploading frames to RunPod.
# Usage: ./scripts/prep_frames.sh [loop_count]
#   loop_count defaults to 2 (gives 16 frames from 8-frame source)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_GIF="$REPO_DIR/assets/cat_walk_wireframe.gif"
OUT_DIR="$REPO_DIR/frames"
LOOP_COUNT="${1:-2}"

if [ ! -f "$SRC_GIF" ]; then
    echo "ERROR: $SRC_GIF not found"
    exit 1
fi

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/frame_*.png

echo "==> Source GIF info:"
ffprobe -v quiet -select_streams v:0 \
    -show_entries stream=nb_frames,r_frame_rate,width,height \
    -of default=noprint_wrappers=1 "$SRC_GIF"

echo ""
echo "==> Extracting frames (loop_count=$LOOP_COUNT) → $OUT_DIR"

ffmpeg -loglevel warning \
    -stream_loop "$LOOP_COUNT" \
    -i "$SRC_GIF" \
    -vf "fps=5,scale=512:512:flags=lanczos" \
    "$OUT_DIR/frame_%04d.png"

FRAME_COUNT=$(ls "$OUT_DIR"/frame_*.png | wc -l | tr -d ' ')
echo "==> Extracted $FRAME_COUNT frames"

if [ "$FRAME_COUNT" -lt 16 ]; then
    echo "WARNING: fewer than 16 frames — AnimateDiff needs at least 16."
    echo "         Re-run with a higher loop_count: ./scripts/prep_frames.sh 4"
fi

echo ""
echo "Frames ready in: $OUT_DIR"
echo "Upload to RunPod: scp -r $OUT_DIR <pod-ip>:/workspace/ComfyUI/input/frames/"
