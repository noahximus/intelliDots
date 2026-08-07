"""OpenAI-compatible proxy and local-model repair loop."""

from __future__ import annotations

import json
import logging
import os
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any

from .normalizer import (
    ToolRegistry,
    normalize_message,
    parse_repair_content,
)

LOG = logging.getLogger("local-llm-wrapper")


class BackendError(RuntimeError):
    def __init__(self, status: int, body: bytes, content_type: str = "application/json"):
        super().__init__(f"backend returned HTTP {status}")
        self.status = status
        self.body = body
        self.content_type = content_type


class RepairError(RuntimeError):
    pass


@dataclass
class ProxyConfig:
    backend_url: str = "http://127.0.0.1:8081"
    timeout_seconds: float = 300.0
    repair_attempts: int = 2
    use_json_schema: bool = True
    disable_thinking: bool = True
    max_repair_tokens: int = 2048

    @classmethod
    def from_env(cls) -> "ProxyConfig":
        return cls(
            backend_url=os.getenv("LOCAL_LLM_WRAPPER_BACKEND", "http://127.0.0.1:8081").rstrip("/"),
            timeout_seconds=float(os.getenv("LOCAL_LLM_WRAPPER_TIMEOUT", "300")),
            repair_attempts=max(1, int(os.getenv("LOCAL_LLM_WRAPPER_REPAIR_ATTEMPTS", "2"))),
            use_json_schema=os.getenv("LOCAL_LLM_WRAPPER_USE_JSON_SCHEMA", "1").lower()
            not in {"0", "false", "no"},
            disable_thinking=os.getenv("LOCAL_LLM_WRAPPER_DISABLE_THINKING", "1").lower()
            not in {"0", "false", "no"},
            max_repair_tokens=int(os.getenv("LOCAL_LLM_WRAPPER_MAX_REPAIR_TOKENS", "2048")),
        )


class BackendClient:
    def __init__(self, config: ProxyConfig):
        self.config = config

    def request(
        self,
        method: str,
        path: str,
        body: bytes | None = None,
        headers: dict[str, str] | None = None,
    ) -> tuple[int, bytes, str]:
        forwarded_headers = {"Accept": "application/json"}
        if body is not None:
            forwarded_headers["Content-Type"] = "application/json"
        if headers and headers.get("Authorization"):
            forwarded_headers["Authorization"] = headers["Authorization"]
        request = urllib.request.Request(
            f"{self.config.backend_url}{path}",
            data=body,
            headers=forwarded_headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=self.config.timeout_seconds) as response:
                return (
                    response.status,
                    response.read(),
                    response.headers.get("Content-Type", "application/json"),
                )
        except urllib.error.HTTPError as error:
            raise BackendError(
                error.code,
                error.read(),
                error.headers.get("Content-Type", "application/json"),
            ) from error
        except urllib.error.URLError as error:
            raise BackendError(
                502,
                json.dumps(
                    {
                        "error": {
                            "type": "backend_unavailable",
                            "message": str(error.reason),
                        }
                    }
                ).encode(),
            ) from error

    def chat(self, payload: dict[str, Any]) -> dict[str, Any]:
        _, body, _ = self.request(
            "POST",
            "/v1/chat/completions",
            json.dumps(payload).encode(),
        )
        try:
            response = json.loads(body)
        except json.JSONDecodeError as error:
            raise BackendError(
                502,
                json.dumps(
                    {
                        "error": {
                            "type": "invalid_backend_response",
                            "message": "Backend did not return JSON",
                        }
                    }
                ).encode(),
            ) from error
        if not isinstance(response, dict):
            raise BackendError(502, b'{"error":{"message":"Backend response must be an object"}}')
        return response


class CompletionProcessor:
    def __init__(self, client: BackendClient, config: ProxyConfig):
        self.client = client
        self.config = config

    def complete(self, request_payload: dict[str, Any]) -> dict[str, Any]:
        backend_payload = dict(request_payload)
        backend_payload["stream"] = False
        if self.config.disable_thinking:
            template_options = dict(backend_payload.get("chat_template_kwargs") or {})
            template_options["enable_thinking"] = False
            backend_payload["chat_template_kwargs"] = template_options
        response = self.client.chat(backend_payload)

        choice, message = _first_message(response)
        tools = request_payload.get("tools")
        result = normalize_message(message, tools)

        if result.tool_calls:
            _install_calls(choice, message, result.tool_calls)
            LOG.info("normalized %d tool call(s) from %s", len(result.tool_calls), result.source)
            return response

        if not result.needs_repair:
            return response

        repaired = self._repair(
            original_request=request_payload,
            malformed_message=message,
            initial_errors=result.errors,
        )
        if not repaired:
            raise RepairError(
                "Local model indicated tool intent but no valid tool call could be recovered"
            )
        _install_calls(choice, message, repaired)
        LOG.info("repaired %d tool call(s) with a constrained second pass", len(repaired))
        return response

    def _repair(
        self,
        original_request: dict[str, Any],
        malformed_message: dict[str, Any],
        initial_errors: list[str],
    ) -> list[dict[str, Any]]:
        registry = ToolRegistry(original_request.get("tools"))
        previous_output: Any = malformed_message
        errors = initial_errors or ["No machine-readable tool call was found."]

        for attempt in range(1, self.config.repair_attempts + 1):
            payload = self._repair_payload(
                original_request, registry, previous_output, errors
            )
            try:
                repair_response = self.client.chat(payload)
            except BackendError as error:
                if self.config.use_json_schema and error.status in {400, 422}:
                    LOG.warning("backend rejected response_format; retrying repair without it")
                    payload.pop("response_format", None)
                    repair_response = self.client.chat(payload)
                else:
                    raise

            _, repair_message = _first_message(repair_response)
            native_result = normalize_message(
                repair_message, original_request.get("tools")
            )
            if native_result.tool_calls:
                return native_result.tool_calls

            content = repair_message.get("content")
            candidates = parse_repair_content(content if isinstance(content, str) else "")
            calls: list[dict[str, Any]] = []
            errors = []
            for index, candidate in enumerate(candidates):
                call, candidate_errors = registry.validate_call(candidate, index)
                if call:
                    calls.append(call)
                errors.extend(candidate_errors)
            if calls and not errors:
                return calls
            if candidates == [] and _is_explicit_no_call(content):
                return []
            previous_output = repair_message
            errors = errors or [f"Repair attempt {attempt} returned no valid calls."]

        raise RepairError("; ".join(errors))

    def _repair_payload(
        self,
        original_request: dict[str, Any],
        registry: ToolRegistry,
        previous_output: Any,
        errors: list[str],
    ) -> dict[str, Any]:
        source_messages = original_request.get("messages", [])
        recent_messages = source_messages[-4:] if isinstance(source_messages, list) else []
        repair_input = {
            "recent_conversation": recent_messages,
            "malformed_assistant_output": previous_output,
            "validation_errors": errors,
            "available_tools": registry.prompt_definitions(),
        }
        payload: dict[str, Any] = {
            "model": original_request.get("model"),
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "You are a deterministic tool-call formatter. Recover the assistant's "
                        "intended tool calls without changing its intent. Return only one JSON "
                        "object with a tool_calls array. Every item must contain exactly name and "
                        "arguments. Use an exact available tool name and make arguments comply "
                        "with that tool's JSON Schema. Do not claim a tool ran. If no tool was "
                        "actually intended, return {\"tool_calls\":[]}."
                    ),
                },
                {
                    "role": "user",
                    "content": json.dumps(repair_input, ensure_ascii=False),
                },
            ],
            "stream": False,
            "temperature": 0,
            "max_tokens": self.config.max_repair_tokens,
            "chat_template_kwargs": {"enable_thinking": False},
        }
        if self.config.use_json_schema:
            payload["response_format"] = {
                "type": "json_schema",
                "schema": registry.repair_schema(),
            }
        return payload


def _first_message(response: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    choices = response.get("choices")
    if not isinstance(choices, list) or not choices or not isinstance(choices[0], dict):
        raise BackendError(502, b'{"error":{"message":"Backend response has no choice"}}')
    choice = choices[0]
    message = choice.get("message")
    if not isinstance(message, dict):
        raise BackendError(502, b'{"error":{"message":"Backend choice has no message"}}')
    return choice, message


def _install_calls(
    choice: dict[str, Any],
    message: dict[str, Any],
    calls: list[dict[str, Any]],
) -> None:
    message["role"] = "assistant"
    message["content"] = None
    message["tool_calls"] = calls
    choice["finish_reason"] = "tool_calls"


def _is_explicit_no_call(content: Any) -> bool:
    if not isinstance(content, str):
        return False
    try:
        value = json.loads(content)
    except json.JSONDecodeError:
        return False
    return isinstance(value, dict) and value.get("tool_calls") == []


def make_sse(response: dict[str, Any]) -> bytes:
    """Convert a buffered completion into OpenAI-compatible SSE chunks."""
    choice, message = _first_message(response)
    base = {
        "id": response.get("id", f"chatcmpl-wrapper-{int(time.time())}"),
        "object": "chat.completion.chunk",
        "created": response.get("created", int(time.time())),
        "model": response.get("model", "local-llm"),
    }
    chunks: list[dict[str, Any]] = [
        {
            **base,
            "choices": [
                {
                    "index": 0,
                    "delta": {"role": "assistant"},
                    "finish_reason": None,
                }
            ],
        }
    ]
    content = message.get("content")
    if isinstance(content, str) and content:
        chunks.append(
            {
                **base,
                "choices": [
                    {
                        "index": 0,
                        "delta": {"content": content},
                        "finish_reason": None,
                    }
                ],
            }
        )
    for index, call in enumerate(message.get("tool_calls", [])):
        chunks.append(
            {
                **base,
                "choices": [
                    {
                        "index": 0,
                        "delta": {
                            "tool_calls": [
                                {
                                    "index": index,
                                    "id": call["id"],
                                    "type": "function",
                                    "function": call["function"],
                                }
                            ]
                        },
                        "finish_reason": None,
                    }
                ],
            }
        )
    chunks.append(
        {
            **base,
            "choices": [
                {
                    "index": 0,
                    "delta": {},
                    "finish_reason": choice.get("finish_reason", "stop"),
                }
            ],
        }
    )
    lines = [f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n" for chunk in chunks]
    lines.append("data: [DONE]\n\n")
    return "".join(lines).encode()
