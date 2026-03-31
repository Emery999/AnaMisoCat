# Cat Animation Pipeline: ComfyUI + AnimateDiff + ControlNet + IP-Adapter

## Project Goal
Take illustrated cat reference images (style sheets, pose sheets, rendered walking cat) and a wireframe walking GIF, and produce a fully rendered walking animation matching the illustration style.

## Source Assets
- `signal-2026-03-30-193621_002.gif` — wireframe walk cycle GIF (motion template)
- `signal-2026-03-30-193621.jpeg` — fully rendered walking cat (primary style reference)
- `signal-2026-03-30-193640_002.webp` — pose sheet, 9 angles (character grounding)
- `signal-2026-03-30-193640.webp` — action poses: naps, chase, fall (secondary reference)

---

## Core Stack
| Tool | Role |
|------|------|
| ComfyUI | Workflow engine |
| AnimateDiff-Evolved | Temporal consistency across frames |
| ControlNet (lineart) | Motion guidance from wireframe GIF |
| IP-Adapter Plus | Style/character lock from rendered references |
| VideoHelperSuite | GIF frame I/O |

---

## Step 1: ComfyUI Base Install

```bash
git clone https://github.com/comfyanonymous/ComfyUI
cd ComfyUI
pip install -r requirements.txt
```

Install ComfyUI Manager (makes all other installs easier):
```bash
cd custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager
cd ..
python main.py
```

Open browser at `http://127.0.0.1:8188` — Manager will appear in the menu.

---

## Step 2: Custom Nodes (install via ComfyUI Manager)

Search and install each of these in Manager → Install Custom Nodes:

- `ComfyUI-AnimateDiff-Evolved` — by Kosinkadink (use this fork, not the original)
- `ComfyUI_IPAdapter_plus`
- `comfyui_controlnet_aux`
- `ComfyUI-VideoHelperSuite`

---

## Step 3: Model Downloads

### Base Checkpoint (illustration-friendly)
Choose one — place in `ComfyUI/models/checkpoints/`:
- **toonyou** — https://civitai.com/models/30240 (best for this style)
- **dreamshaper_8** — https://civitai.com/models/4384 (good fallback)

### AnimateDiff Motion Module
Place in `ComfyUI/custom_nodes/ComfyUI-AnimateDiff-Evolved/models/`:
- `mm_sd_v15_v2.ckpt`
- Download from: https://huggingface.co/guoyww/animatediff/tree/main

### ControlNet Model (lineart)
Place in `ComfyUI/models/controlnet/`:
- `control_v11p_sd15_lineart.pth`
- Download from: https://huggingface.co/lllyasviel/ControlNet-v1-1/tree/main

### IP-Adapter Models
Place in `ComfyUI/models/ipadapter/`:
- `ip-adapter_sd15.safetensors`
- `ip-adapter-plus_sd15.safetensors` ← prefer this one
- Download from: https://huggingface.co/h94/IP-Adapter/tree/main/models

### CLIP Vision Encoder (required by IP-Adapter)
Place in `ComfyUI/models/clip_vision/`:
- `clip_vision_g.safetensors`
- Same repo: https://huggingface.co/h94/IP-Adapter/tree/main/models/image_encoder

---

## Step 4: Prepare Source Assets

### Extract wireframe GIF frames
```bash
mkdir frames
ffmpeg -i signal-2026-03-30-193621_002.gif frames/frame_%04d.png
```

Check how many frames you got:
```bash
ls frames/ | wc -l
```

If fewer than 16, loop the GIF first to get more frames:
```bash
# Create a 3x looped version first
ffmpeg -stream_loop 3 -i signal-2026-03-30-193621_002.gif -vf "fps=12" frames/frame_%04d.png
```

### Style reference images
Keep these accessible for IP-Adapter loading in ComfyUI:
- Primary: `signal-2026-03-30-193621.jpeg` (rendered walking cat — weight 0.7)
- Secondary: `signal-2026-03-30-193640_002.webp` (pose sheet — weight 0.3)

---

## Step 5: ComfyUI Workflow Structure

### Recommended starting point
Rather than building from scratch, download a pre-built workflow JSON:
1. Go to https://civitai.com/search/models?modelType=Workflows
2. Search: `animatediff ipadapter controlnet`
3. Import the JSON via ComfyUI → Load button

### Node chain (conceptual)
```
[Load Image: rendered cat JPEG]
    → [IP-Adapter Plus] (weight: 0.65)
    
[Load Image Sequence: wireframe frames/]
    → [ControlNet Aux Preprocessor: Lineart]
    → [Apply ControlNet] (strength: 0.70)

Both → [KSampler with AnimateDiff]
    → [VAE Decode]
    → [Video Combine / GIF Export]
```

---

## Step 6: Key Parameters

### AnimateDiff settings
| Parameter | Value |
|-----------|-------|
| Context length | 16 frames |
| Context overlap | 4 |
| Motion module | mm_sd_v15_v2 |

### KSampler settings
| Parameter | Value |
|-----------|-------|
| Steps | 20–25 |
| CFG Scale | 7–8 |
| Sampler | euler_ancestral or dpmpp_2m |
| Scheduler | karras |
| Denoise | 0.75–0.85 |

### ControlNet settings
| Parameter | Value |
|-----------|-------|
| Model | control_v11p_sd15_lineart |
| Strength | 0.70 (start here) |
| Start percent | 0.0 |
| End percent | 0.85 |

### IP-Adapter settings
| Parameter | Value |
|-----------|-------|
| Model | ip-adapter-plus_sd15 |
| Weight (primary ref) | 0.65–0.75 |
| Weight (pose sheet) | 0.25–0.35 |

---

## Step 7: Prompts

### Positive prompt
```
fluffy orange and cream longhair cat walking, side view, 
illustration style, soft warm tones, detailed fur texture, 
children's book illustration, white background, 
consistent character design, warm amber and cream colors
```

### Negative prompt
```
realistic, photographic, 3d render, deformed, extra limbs, 
mutation, bad anatomy, inconsistent style, dark background, 
multiple cats, blurry, low quality, watermark
```

---

## Step 8: Recommended Workflow Order

1. **Single frame test first** — disable AnimateDiff, run KSampler on one frame. Nail the style match before adding temporal complexity.
2. **Add ControlNet** — confirm it follows the wireframe pose correctly on a single frame.
3. **Enable AnimateDiff** — run full sequence. Check for temporal drift.
4. **Dial IP-Adapter weight** — if character drifts between frames, increase IP-Adapter weight toward 0.8. If it loses the motion, reduce toward 0.5.
5. **Export** — use VideoHelperSuite to export as GIF or MP4.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Character looks nothing like reference | Increase IP-Adapter weight; try ip-adapter-plus over ip-adapter |
| Motion doesn't follow wireframe | Increase ControlNet strength toward 0.85 |
| Flickering between frames | Reduce denoise to 0.7; ensure AnimateDiff context overlap is set to 4 |
| Style too realistic / not illustrative | Switch checkpoint to toonyou; add "illustration" tokens to prompt |
| Legs look wrong | Feed pose sheet as secondary IP-Adapter reference at low weight (0.2) |
| Output too short | Loop the source GIF before frame extraction (see Step 4) |

---

## Useful Links

- ComfyUI repo: https://github.com/comfyanonymous/ComfyUI
- AnimateDiff-Evolved: https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved
- AnimateDiff-Evolved wiki (pre-built workflows): https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved/wiki
- IP-Adapter repo: https://github.com/tencent-ailab/IP-Adapter
- ComfyUI_IPAdapter_plus: https://github.com/cubiq/ComfyUI_IPAdapter_plus
- CivitAI workflow search: https://civitai.com/search/models?modelType=Workflows
- HuggingFace AnimateDiff models: https://huggingface.co/guoyww/animatediff

---

## Notes for Claude Code
- All source image files should be in the working directory alongside this file
- The ffmpeg commands in Step 4 should be run in terminal before starting ComfyUI
- ComfyUI runs as a local server — keep it running in a separate terminal while working
- Workflow JSON files can be version-controlled alongside this project
- If GPU VRAM is under 8GB, add `--lowvram` flag when launching ComfyUI: `python main.py --lowvram`
