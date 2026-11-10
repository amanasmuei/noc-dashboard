#!/usr/bin/env python3
"""TNOC dashboard: static server + tiny shared JSON store.

    python3 serve.py [port]          # default 8080
    open http://<this-mac-ip>:8080   # same latest data in every browser on the LAN

Store is data/ntt.json (path -> doc), written atomically. No cloud, no auth:
anyone who can reach the port can publish. Run it on a machine you trust.
"""
import json
import os
import re
import tempfile
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(ROOT, "data", "ntt.json")
PATH = re.compile(r"(ntt|uploads|meta)/[A-Za-z0-9_-]{1,40}")
LOCK = threading.Lock()


def load():
    try:
        with open(DATA, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save(store):
    os.makedirs(os.path.dirname(DATA), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(DATA))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(store, f, separators=(",", ":"), ensure_ascii=False)
    os.replace(tmp, DATA)
    os.chmod(DATA, 0o644)   # host user must be able to copy the store for backup


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def reply(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("cache-control", "no-store")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.split("?")[0] == "/api/all":
            with LOCK:
                return self.reply(load())
        if self.path.split("?")[0] == "/api/health":
            return self.reply({"ok": True, "keys": len(load())})
        return super().do_GET()

    def do_POST(self):
        if self.path.split("?")[0] != "/api/doc":
            return self.reply({"error": "not found"}, 404)
        try:
            n = int(self.headers.get("content-length") or 0)
            req = json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            return self.reply({"error": "bad json"}, 400)
        path = req.get("path") or ""
        if not isinstance(path, str) or not PATH.fullmatch(path):
            return self.reply({"error": "bad path"}, 400)
        with LOCK:
            store = load()
            if req.get("delete"):
                store.pop(path, None)
            elif isinstance(req.get("data"), dict):
                store[path] = req["data"]
            else:
                return self.reply({"error": "bad data"}, 400)
            save(store)
        return self.reply({"ok": True, "keys": len(store)})

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    import sys

    port = int(sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PORT", "8080"))
    print(f"TNOC dashboard  ->  http://localhost:{port}")
    print(f"store: {DATA}")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
