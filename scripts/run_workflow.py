#!/usr/bin/env python3
"""Submit a ComfyUI workflow JSON via API and poll until complete."""

import json, urllib.request, urllib.error, time, sys, os, argparse

COMFY_URL = os.environ.get("COMFY_URL", "http://127.0.0.1:8188")


def submit(workflow_path):
    with open(workflow_path) as f:
        data = json.load(f)

    # Strip _meta keys from top level and from each node
    prompt = {}
    for k, v in data.items():
        if k.startswith("_"):
            continue
        prompt[k] = {kk: vv for kk, vv in v.items() if not kk.startswith("_")}

    payload = json.dumps({"prompt": prompt}).encode()
    req = urllib.request.Request(
        f"{COMFY_URL}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"HTTP {e.code} submitting prompt:\n{body}")
        sys.exit(1)

    prompt_id = result["prompt_id"]
    print(f"Submitted  prompt_id: {prompt_id}")
    print("Polling for completion", end="", flush=True)

    while True:
        time.sleep(4)
        resp = urllib.request.urlopen(f"{COMFY_URL}/history/{prompt_id}")
        history = json.loads(resp.read())
        if prompt_id not in history:
            print(".", end="", flush=True)
            continue

        entry = history[prompt_id]
        status = entry.get("status", {})

        if status.get("status_str") == "error" or any(
            m.get("type") == "error" for m in status.get("messages", [])
        ):
            print("\nError during execution:")
            print(json.dumps(entry.get("status"), indent=2))
            sys.exit(1)

        if status.get("completed"):
            print("\nDone!")
            for node_id, output in entry.get("outputs", {}).items():
                for img in output.get("images", []):
                    subfolder = img.get("subfolder") or "output"
                    print(f"  Saved: {subfolder}/{img['filename']}")
            return

        print(".", end="", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run a ComfyUI workflow via API")
    parser.add_argument("workflow", help="Path to workflow JSON file")
    args = parser.parse_args()
    submit(args.workflow)
