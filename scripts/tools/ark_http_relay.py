#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
本机 HTTP → 火山方舟 HTTPS 转发（仅标准库）。

用于：游戏引擎内置 HTTP 访问公网 HTTPS 时出现极快 404、OnError 无响应体等
「中间层」问题时，让引擎只请求 http://127.0.0.1，由本脚本用 urllib 转发到真实 Ark URL。

用法（与跑 UrhoX 服务端的同一台机器）：
  set ARK_UPSTREAM=https://ark.cn-beijing.volces.com/api/v3/chat/completions
  python scripts/tools/ark_http_relay.py

在 LLMConfig.lua 中设置：
  HTTP_RELAY_URL = "http://127.0.0.1:8765/api/v3/chat/completions"
  API_URL 仍填真实方舟地址（便于对照日志；中继以环境变量为准）

可选环境变量：
  ARK_UPSTREAM — 默认 https://ark.cn-beijing.volces.com/api/v3/chat/completions
  RELAY_PORT   — 默认 8765
"""

from __future__ import annotations

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

DEFAULT_UPSTREAM = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"


class RelayHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write(fmt % args + "\n")

    def do_POST(self) -> None:
        path = self.path.split("?", 1)[0]
        if not path or (
            path != "/"
            and "chat/completions" not in path
            and not path.rstrip("/").endswith("completions")
        ):
            self.send_error(404, "only chat completions POST supported")
            return

        try:
            n = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            n = 0
        body = self.rfile.read(n) if n else b""

        upstream = os.environ.get("ARK_UPSTREAM", DEFAULT_UPSTREAM).strip()
        req = Request(upstream, data=body, method="POST")
        req.add_header("Content-Type", self.headers.get("Content-Type", "application/json"))
        auth = self.headers.get("Authorization")
        if auth:
            req.add_header("Authorization", auth)
        ua = self.headers.get("User-Agent")
        if ua:
            req.add_header("User-Agent", ua)
        req.add_header("Accept", self.headers.get("Accept", "application/json"))

        try:
            with urlopen(req, timeout=120) as resp:
                out = resp.read()
                self.send_response(200)
                ct = resp.headers.get("Content-Type", "application/json")
                self.send_header("Content-Type", ct)
                self.send_header("Content-Length", str(len(out)))
                self.end_headers()
                self.wfile.write(out)
        except HTTPError as e:
            err_body = e.read()
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)
        except URLError as e:
            msg = json.dumps({"error": {"message": str(e.reason), "type": "relay_url_error"}}).encode(
                "utf-8"
            )
            self.send_response(502)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)


def main() -> None:
    port = int(os.environ.get("RELAY_PORT", "8765"))
    host = os.environ.get("RELAY_BIND", "127.0.0.1")
    upstream = os.environ.get("ARK_UPSTREAM", DEFAULT_UPSTREAM)
    print(f"ark_http_relay listening http://{host}:{port} -> {upstream}", file=sys.stderr)
    HTTPServer((host, port), RelayHandler).serve_forever()


if __name__ == "__main__":
    main()
