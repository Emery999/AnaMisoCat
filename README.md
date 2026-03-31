# AnaMisoCat — Walk Cycle Animation Pipeline

Render an illustrated cat walk cycle from a wireframe GIF using ComfyUI + AnimateDiff + ControlNet + IP-Adapter, running on a cheap cloud GPU (RunPod).

## Source Assets

| File | Role |
|------|------|
| `assets/cat_walk_rendered.jpeg` | Primary style reference — rendered walking cat |
| `assets/cat_walk_wireframe.gif` | Motion template — 8-frame wireframe walk cycle |
| `assets/cat_pose_sheet.webp` | 9-angle pose sheet — character consistency |
| `assets/cat_action_poses.webp` | Secondary action poses |

---

## Step 0 — Local frame prep (your machine)

Requires: `ffmpeg`

```bash
./scripts/prep_frames.sh
```

This loops the 8-frame wireframe GIF to produce 16 frames (AnimateDiff minimum), resized to 512×512, saved to `frames/`.

Verify: `ls frames/ | wc -l` should print `16`.

---

## Step 1 — Spin up RunPod

1. Go to [runpod.io](https://runpod.io) → **Explore** → search template: `ComfyUI`
2. Select **RTX 3090** (~$0.44/hr, 24GB VRAM) — cheapest that handles this stack reliably
3. Deploy with **at least 30GB disk** (models are ~8GB total)
4. Once running, open the **ComfyUI** link (port 8188) to confirm it loads

---

## Step 2 — Upload assets to RunPod

From your machine, use the RunPod file manager or SSH/SCP:

```
ComfyUI/input/
  cat_walk_rendered.jpeg    ← from assets/
  cat_pose_sheet.webp       ← from assets/
  frames/                   ← entire frames/ directory
    frame_0001.png
    frame_0002.png
    ...
```

---

## Step 3 — Install custom nodes (RunPod terminal)

```bash
git clone https://github.com/YOUR_FORK/AnaMisoCat /workspace/AnaMisoCat
cd /workspace/AnaMisoCat
bash setup/install_nodes.sh
```

Then restart ComfyUI:
```bash
cd /workspace/ComfyUI && python main.py --listen 0.0.0.0
```

---

## Step 4 — Download models (RunPod terminal)

For the toonyou checkpoint, get a free API key at [civitai.com](https://civitai.com) → Account Settings → API Keys.

```bash
export CIVITAI_API_KEY=your_key_here
bash /workspace/AnaMisoCat/setup/download_models.sh
```

If you skip the API key, the script will print the manual download URL. Place the file at:
`/workspace/ComfyUI/models/checkpoints/toonyou_beta6.safetensors`

**Expected model sizes:**
| Model | Size |
|-------|------|
| toonyou_beta6.safetensors | ~2.1 GB |
| mm_sd_v15_v2.ckpt | ~1.7 GB |
| control_v11p_sd15_lineart.pth | ~1.4 GB |
| ip-adapter-plus_sd15.safetensors | ~0.8 GB |
| clip_vision_g.safetensors | ~3.5 GB |

---

## Step 5 — Load and run the workflow

1. In ComfyUI browser UI → **Load** → select `workflows/cat_walk_v1.json`
2. **First run: single frame style check**
   - Right-click the `AnimateDiff Loader` node → **Bypass**
   - Set `EmptyLatentImage` batch_size to `1`
   - Set `VHS_LoadImages` image_load_cap to `1`
   - Run — confirm the rendered style matches the reference cat
3. **Second run: add ControlNet check**
   - Unbypass AnimateDiff still off, confirm single frame follows the wireframe pose
4. **Full run: enable AnimateDiff**
   - Remove bypass from AnimateDiff node
   - Restore batch_size to `16`, image_load_cap to `16`
   - Queue prompt

---

## Step 6 — Export

Output GIF is auto-saved by the `VHS_VideoCombine` node in ComfyUI's output folder.

To assemble locally after downloading frames:
```bash
./scripts/make_gif.sh output/frames cat_walk_out
# produces output/cat_walk_out.gif and output/cat_walk_out.mp4
```

---

## Tuning Reference

### If the character drifts between frames
Increase IP-Adapter primary weight toward `0.8` (node 8, `weight` field).

### If the animation doesn't follow the wireframe
Increase ControlNet strength toward `0.85` (node 13, `strength` field).

### If there's flickering
- Reduce KSampler `denoise` to `0.70`
- Confirm AnimateDiff `context_overlap` is `4`

### If style is too realistic
- Confirm checkpoint is toonyou (not dreamshaper)
- Add `"illustration"` and `"painterly"` to positive prompt

### If output is too short / not looping
Re-run `prep_frames.sh` with more loops: `./scripts/prep_frames.sh 4` (gives 32 frames).

---

## Cost estimate

| Activity | Time | Cost |
|----------|------|------|
| Setup + model downloads | ~20 min | ~$0.15 |
| Single frame test (2–3 runs) | ~5 min | ~$0.04 |
| Full 16-frame run | ~10–15 min | ~$0.11 |
| **Total first session** | ~45 min | **~$0.35** |

Stop the pod when done — storage persists so models don't need re-downloading.

---

## Stack

| Tool | Version/Fork | Role |
|------|-------------|------|
| ComfyUI | latest | Workflow engine |
| ComfyUI-AnimateDiff-Evolved | Kosinkadink fork | Temporal consistency |
| ComfyUI_IPAdapter_plus | cubiq | Style/character lock |
| comfyui_controlnet_aux | Fannovel16 | Lineart preprocessor |
| ComfyUI-VideoHelperSuite | Kosinkadink | Frame I/O |
| toonyou_beta6 | CivitAI 30240 | Illustration-style checkpoint |
| mm_sd_v15_v2 | guoyww/animatediff | Motion module |
| control_v11p_sd15_lineart | lllyasviel | ControlNet lineart |
| ip-adapter-plus_sd15 | h94/IP-Adapter | IP-Adapter model |
