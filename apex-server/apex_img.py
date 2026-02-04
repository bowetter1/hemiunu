#!/usr/bin/env python3
"""
Apex Image CLI — lightweight wrapper for sub-agents (Gemini, Codex).

Usage:
  python3 apex_img.py search "modern office" [--orientation landscape] [--count 3]
  python3 apex_img.py generate "a hero image of..." [--filename hero.png] [--size 1536x1024]

Reads API keys from ~/.apex/ files or environment variables.
"""

import argparse
import base64
import json
import os
import re
import sys


def _read_key(env_name: str, file_name: str) -> str:
    val = os.environ.get(env_name, "")
    if val:
        return val
    home = os.path.expanduser("~")
    path = os.path.join(home, ".apex", file_name)
    try:
        return open(path).read().strip()
    except FileNotFoundError:
        return ""


def cmd_search(args):
    import httpx

    api_key = _read_key("PEXELS_API_KEY", "pexels_key")
    if not api_key:
        print(json.dumps({"error": "PEXELS_API_KEY not set"}))
        sys.exit(1)

    resp = httpx.get(
        "https://api.pexels.com/v1/search",
        headers={"Authorization": api_key},
        params={
            "query": args.query,
            "orientation": args.orientation,
            "per_page": args.count,
            "size": "large",
        },
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()

    photos = []
    for p in data.get("photos", []):
        src = p.get("src", {})
        photos.append({
            "url": src.get("large2x") or src.get("large") or src.get("original"),
            "photographer": p.get("photographer", ""),
            "alt": p.get("alt", args.query),
        })

    print(json.dumps({"photos": photos}, indent=2))


def cmd_generate(args):
    from openai import OpenAI

    api_key = _read_key("OPENAI_API_KEY", "openai_key")
    if not api_key:
        print(json.dumps({"error": "OPENAI_API_KEY not set"}))
        sys.exit(1)

    client = OpenAI(api_key=api_key)
    response = client.images.generate(
        model="gpt-image-1",
        prompt=args.prompt,
        n=1,
        size=args.size,
        quality="medium",
    )

    image_data = response.data[0]
    safe_name = re.sub(r"[^a-zA-Z0-9._-]", "", args.filename) or "generated.png"

    if hasattr(image_data, "b64_json") and image_data.b64_json:
        image_bytes = base64.b64decode(image_data.b64_json)
    elif hasattr(image_data, "url") and image_data.url:
        import httpx
        image_bytes = httpx.get(image_data.url, timeout=30).content
    else:
        print(json.dumps({"error": "No image data returned"}))
        sys.exit(1)

    out_path = os.path.join("images", safe_name)
    os.makedirs("images", exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(image_bytes)

    print(json.dumps({
        "path": out_path,
        "size_bytes": len(image_bytes),
    }))


def main():
    parser = argparse.ArgumentParser(description="Apex Image CLI")
    sub = parser.add_subparsers(dest="command")

    sp = sub.add_parser("search", help="Search Pexels for stock photos")
    sp.add_argument("query", help="Search query (2-4 words)")
    sp.add_argument("--orientation", default="landscape", choices=["landscape", "portrait", "square"])
    sp.add_argument("--count", type=int, default=3)

    gp = sub.add_parser("generate", help="Generate AI image with GPT-Image-1")
    gp.add_argument("prompt", help="Image description")
    gp.add_argument("--filename", default="generated.png")
    gp.add_argument("--size", default="1536x1024", choices=["1024x1024", "1536x1024", "1024x1536"])

    args = parser.parse_args()
    if args.command == "search":
        cmd_search(args)
    elif args.command == "generate":
        cmd_generate(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
