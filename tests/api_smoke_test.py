#!/usr/bin/env python3
import json
import sys
import urllib.error
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000"


def call(path: str, method: str = "GET", payload=None):
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8")
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {"raw": body}
        return exc.code, parsed


def main():
    status, health = call("/health")
    print("health:", status, health)

    status, auth = call("/api/v1/auth/status")
    print("auth:", status, auth)
    if not auth.get("authenticated"):
        print("AUTH REQUIRED: run 'codex login' or POST /api/v1/auth/device/start")
        return 2

    status, result = call(
        "/api/v1/query",
        method="POST",
        payload={
            "text": "請用一句繁體中文介紹 BMS。",
            "device": "apple_watch",
            "locale": "zh-TW",
        },
    )
    print("query:", status, result)

    if status != 200 or not result.get("ok") or not result.get("reply"):
        return 1

    print("PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
