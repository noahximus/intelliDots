"""Threaded HTTP server for the OpenAI-compatible wrapper."""

from __future__ import annotations

import json
import logging
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlsplit

from .proxy import (
    BackendClient,
    BackendError,
    CompletionProcessor,
    ProxyConfig,
    RepairError,
    make_sse,
)

LOG = logging.getLogger("local-llm-wrapper")
MAX_REQUEST_BYTES = 16 * 1024 * 1024


class WrapperServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], config: ProxyConfig):
        super().__init__(address, WrapperHandler)
        self.config = config
        self.client = BackendClient(config)
        self.processor = CompletionProcessor(self.client, config)


class WrapperHandler(BaseHTTPRequestHandler):
    server: WrapperServer
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802
        path = urlsplit(self.path).path
        if path in {"/health", "/healthz"}:
            self._json(
                200,
                {
                    "status": "ok",
                    "backend": self.server.config.backend_url,
                    "repair_attempts": self.server.config.repair_attempts,
                },
            )
            return
        self._forward("GET")

    def do_POST(self) -> None:  # noqa: N802
        path = urlsplit(self.path).path
        body = self._read_body()
        if body is None:
            return
        if path != "/v1/chat/completions":
            self._forward("POST", body)
            return
        try:
            payload = json.loads(body)
            if not isinstance(payload, dict):
                raise ValueError("request body must be a JSON object")
        except (json.JSONDecodeError, ValueError) as error:
            self._error(400, "invalid_request", str(error))
            return

        wants_stream = payload.get("stream") is True
        try:
            response = self.server.processor.complete(payload)
        except BackendError as error:
            self._bytes(error.status, error.body, error.content_type)
            return
        except RepairError as error:
            self._error(
                422,
                "tool_call_repair_failed",
                f"{error}. No tool was executed; retry or clarify the requested action.",
            )
            return
        except Exception:
            LOG.exception("unexpected wrapper failure")
            self._error(500, "wrapper_error", "Unexpected wrapper failure")
            return

        if wants_stream:
            self._bytes(200, make_sse(response), "text/event-stream")
        else:
            self._json(200, response)

    def _forward(self, method: str, body: bytes | None = None) -> None:
        try:
            status, response, content_type = self.server.client.request(
                method,
                self.path,
                body,
                {"Authorization": self.headers.get("Authorization", "")},
            )
            self._bytes(status, response, content_type)
        except BackendError as error:
            self._bytes(error.status, error.body, error.content_type)

    def _read_body(self) -> bytes | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._error(400, "invalid_request", "Invalid Content-Length")
            return None
        if length <= 0:
            self._error(400, "invalid_request", "Request body is required")
            return None
        if length > MAX_REQUEST_BYTES:
            self._error(413, "request_too_large", "Request exceeds 16 MiB")
            return None
        return self.rfile.read(length)

    def _json(self, status: int, value: Any) -> None:
        self._bytes(
            status,
            json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode(),
            "application/json",
        )

    def _error(self, status: int, error_type: str, message: str) -> None:
        self._json(status, {"error": {"type": error_type, "message": message}})

    def _bytes(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: Any) -> None:
        LOG.info("%s - %s", self.address_string(), format % args)
