"""
mitmproxy addon replicating g1-acq.js behavior for Windows + iPhone Wi-Fi Proxy.
Loads SKU_MAP and FALLBACK directly from g1-acq.js in the same directory.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from mitmproxy import http

BASE_DIR = Path(__file__).resolve().parent
JS_FILE = BASE_DIR / "g1-acq.js"
TARGET_PREFIX = "https://one.google.com/ai?"
CATALOG_PATTERN = re.compile(r"g1\.[a-z0-9._]{2,60}acq")


def _extract_js_object(js_text: str, var_name: str) -> dict[str, str]:
    match = re.search(rf"var\s+{re.escape(var_name)}\s*=\s*(\{{[\s\S]*?\}});", js_text)
    if not match:
        raise ValueError(f"Could not find {var_name} in {JS_FILE.name}")
    return json.loads(match.group(1))


def load_mappings() -> tuple[dict[str, str], dict[str, str]]:
    js_text = JS_FILE.read_text(encoding="utf-8")
    return _extract_js_object(js_text, "SKU_MAP"), _extract_js_object(js_text, "FALLBACK")


SKU_MAP, FALLBACK = load_mappings()
print(f"[g1-acq] Loaded {len(SKU_MAP)} SKU mappings from {JS_FILE.name}")


def response(flow: http.HTTPFlow) -> None:
    url = flow.request.pretty_url
    if flow.request.pretty_host == "one.google.com":
        status = flow.response.status_code if flow.response else "-"
        print(f"[g1-acq] one.google.com ({status}): {url[:140]}")
        if flow.response and flow.response.text and "g1.ios." in flow.response.text and not url.startswith(TARGET_PREFIX):
            print(f"[g1-acq] NOTE: Found g1.ios.* on non-/ai? URL: {url[:140]}")

    if not url.startswith(TARGET_PREFIX):
        return
    if not flow.response or not flow.response.text:
        return

    body = flow.response.text
    all_g1 = list(dict.fromkeys(re.findall(r"g1\.[a-z0-9._-]{2,60}", body)))
    if all_g1:
        print("[g1-acq] All g1.* IDs:", ", ".join(all_g1[:25]))
    catalog = list(dict.fromkeys(CATALOG_PATTERN.findall(body)))
    print("[g1-acq] Catalog:", ", ".join(catalog) or "None")

    out = body
    total = 0
    for src, dst in SKU_MAP.items():
        count = out.count(src)
        if count == 0:
            continue

        if dst not in catalog and FALLBACK.get(dst) in catalog:
            print(f"[g1-acq] Main SKU missing from catalog, fallback {dst} -> {FALLBACK[dst]}")
            dst = FALLBACK[dst]

        out = out.replace(src, dst)
        total += count
        print(f"[g1-acq] {src} -> {dst} x{count}")

    if total:
        flow.response.text = out
        print(f"[g1-acq] Rewrote {total} occurrence(s)")
    else:
        print("[g1-acq] No target SKU matched")
