"""Normalize malformed local-model tool calls into OpenAI-compatible calls."""

from __future__ import annotations

import ast
import json
import re
import uuid
from dataclasses import dataclass, field
from typing import Any

from .schema import validate


TOOL_MARKERS = re.compile(
    r"<tool_call>|</tool_call>|\btool_calls?\b|\bfunction_call\b|"
    r"\b(arguments|parameters)\s*[:=]",
    re.IGNORECASE,
)
ACTION_WORDS = re.compile(
    r"\b(create|write|edit|modify|delete|remove|rename|move|read|search|"
    r"grep|list|run|execute|apply|patch)\b",
    re.IGNORECASE,
)


@dataclass
class ToolDefinition:
    name: str
    description: str
    parameters: dict[str, Any]


@dataclass
class NormalizationResult:
    tool_calls: list[dict[str, Any]] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    needs_repair: bool = False
    detected_intent: bool = False
    source: str = "none"


class ToolRegistry:
    def __init__(self, tools: list[dict[str, Any]] | None):
        self.tools: dict[str, ToolDefinition] = {}
        for entry in tools or []:
            if entry.get("type", "function") != "function":
                continue
            function = entry.get("function", entry)
            name = function.get("name")
            if not isinstance(name, str) or not name:
                continue
            self.tools[name] = ToolDefinition(
                name=name,
                description=str(function.get("description", "")),
                parameters=function.get("parameters")
                if isinstance(function.get("parameters"), dict)
                else {"type": "object"},
            )
        self._normalized_names: dict[str, list[str]] = {}
        for name in self.tools:
            self._normalized_names.setdefault(_normalize_name(name), []).append(name)

    def resolve_name(self, candidate: Any) -> str | None:
        if not isinstance(candidate, str):
            return None
        if candidate in self.tools:
            return candidate
        matches = self._normalized_names.get(_normalize_name(candidate), [])
        return matches[0] if len(matches) == 1 else None

    def looks_like_intent(self, content: str) -> bool:
        if not self.tools or not content.strip():
            return False
        if TOOL_MARKERS.search(content):
            return True
        folded = re.sub(r"[_-]+", " ", content).lower()
        for name in self.tools:
            readable = re.sub(r"[_-]+", " ", name).lower()
            if readable in folded:
                return True
        return bool(ACTION_WORDS.search(content) and re.search(r"\b(file|command|shell|directory)\b", content, re.I))

    def validate_call(self, raw: dict[str, Any], index: int) -> tuple[dict[str, Any] | None, list[str]]:
        function = raw.get("function") if isinstance(raw.get("function"), dict) else raw
        name = self.resolve_name(function.get("name") or function.get("tool"))
        if name is None:
            return None, [f"tool_calls[{index}]: unknown or missing tool name"]

        arguments = function.get("arguments", function.get("parameters", function.get("args", {})))
        if isinstance(arguments, str):
            arguments, parse_error = _parse_arguments(arguments)
            if parse_error:
                return None, [f"tool_calls[{index}] {name}: {parse_error}"]
        if not isinstance(arguments, dict):
            return None, [f"tool_calls[{index}] {name}: arguments must be a JSON object"]

        errors = [
            f"tool_calls[{index}] {name} {error}"
            for error in validate(arguments, self.tools[name].parameters)
        ]
        if errors:
            return None, errors

        call_id = raw.get("id")
        if not isinstance(call_id, str) or not call_id:
            call_id = f"call_{uuid.uuid4().hex[:24]}"
        return {
            "id": call_id,
            "type": "function",
            "function": {
                "name": name,
                "arguments": json.dumps(arguments, ensure_ascii=False, separators=(",", ":")),
            },
        }, []

    def repair_schema(self) -> dict[str, Any]:
        variants: list[dict[str, Any]] = []
        for tool in self.tools.values():
            variants.append(
                {
                    "type": "object",
                    "properties": {
                        "name": {"const": tool.name},
                        "arguments": tool.parameters,
                    },
                    "required": ["name", "arguments"],
                    "additionalProperties": False,
                }
            )
        item_schema: dict[str, Any]
        if len(variants) == 1:
            item_schema = variants[0]
        else:
            item_schema = {"oneOf": variants}
        return {
            "type": "object",
            "properties": {
                "tool_calls": {
                    "type": "array",
                    "items": item_schema,
                    "minItems": 0,
                    "maxItems": 8,
                }
            },
            "required": ["tool_calls"],
            "additionalProperties": False,
        }

    def prompt_definitions(self) -> list[dict[str, Any]]:
        return [
            {
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parameters,
            }
            for tool in self.tools.values()
        ]


def normalize_message(
    message: dict[str, Any], tools: list[dict[str, Any]] | None
) -> NormalizationResult:
    registry = ToolRegistry(tools)
    if not registry.tools:
        return NormalizationResult()

    native = message.get("tool_calls")
    if isinstance(native, list) and native:
        calls, errors = _validate_candidates(native, registry)
        return NormalizationResult(
            tool_calls=calls,
            errors=errors,
            needs_repair=bool(errors),
            detected_intent=True,
            source="native",
        )

    content = _text_content(message.get("content"))
    candidates = extract_candidates(content)
    if candidates:
        calls, errors = _validate_candidates(candidates, registry)
        return NormalizationResult(
            tool_calls=calls,
            errors=errors,
            needs_repair=bool(errors),
            detected_intent=True,
            source="content",
        )

    intent = registry.looks_like_intent(content)
    return NormalizationResult(
        needs_repair=intent,
        detected_intent=intent,
        source="intent" if intent else "none",
    )


def extract_candidates(content: str) -> list[dict[str, Any]]:
    if not content.strip():
        return []
    values: list[Any] = []

    for match in re.finditer(r"<tool_call>\s*(.*?)\s*</tool_call>", content, re.I | re.S):
        parsed = _parse_loose_value(match.group(1))
        if parsed is not None:
            values.append(parsed)

    for match in re.finditer(r"```(?:json|tool_call|tool)?\s*(.*?)```", content, re.I | re.S):
        parsed = _parse_loose_value(match.group(1))
        if parsed is not None:
            values.append(parsed)

    whole = _parse_loose_value(content)
    if whole is not None:
        values.append(whole)

    if not values:
        decoder = json.JSONDecoder()
        for index, char in enumerate(content):
            if char not in "[{":
                continue
            try:
                value, _ = decoder.raw_decode(content[index:])
            except json.JSONDecodeError:
                continue
            values.append(value)

    candidates: list[dict[str, Any]] = []
    for value in values:
        candidates.extend(_canonical_candidates(value))
    if not candidates:
        function_match = re.search(
            r"\b([A-Za-z_][A-Za-z0-9_.-]*)\s*\((\{.*\})\)", content, re.S
        )
        if function_match:
            arguments = _parse_loose_value(function_match.group(2))
            if isinstance(arguments, dict):
                candidates.append(
                    {"name": function_match.group(1), "arguments": arguments}
                )
    return _deduplicate(candidates)


def parse_repair_content(content: str) -> list[dict[str, Any]]:
    parsed = _parse_loose_value(content)
    if parsed is None:
        extracted = extract_candidates(content)
        return extracted
    return _canonical_candidates(parsed)


def _canonical_candidates(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list):
        output: list[dict[str, Any]] = []
        for item in value:
            output.extend(_canonical_candidates(item))
        return output
    if not isinstance(value, dict):
        return []
    if isinstance(value.get("tool_calls"), list):
        return _canonical_candidates(value["tool_calls"])
    if isinstance(value.get("tool_call"), (dict, list)):
        return _canonical_candidates(value["tool_call"])
    if isinstance(value.get("function_call"), dict):
        return _canonical_candidates(value["function_call"])
    if isinstance(value.get("function"), dict):
        return [value]
    if any(key in value for key in ("name", "tool")):
        return [value]
    return []


def _validate_candidates(
    candidates: list[dict[str, Any]], registry: ToolRegistry
) -> tuple[list[dict[str, Any]], list[str]]:
    calls: list[dict[str, Any]] = []
    errors: list[str] = []
    for index, candidate in enumerate(candidates):
        call, call_errors = registry.validate_call(candidate, index)
        if call is not None:
            calls.append(call)
        errors.extend(call_errors)
    if errors:
        return [], errors
    return calls, []


def _parse_arguments(value: str) -> tuple[Any, str | None]:
    parsed = _parse_loose_value(value)
    if parsed is None:
        return None, "arguments are not valid JSON"
    return parsed, None


def _parse_loose_value(value: str) -> Any | None:
    stripped = value.strip()
    if not stripped:
        return None
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        pass
    try:
        parsed = ast.literal_eval(stripped)
    except (ValueError, SyntaxError):
        return None
    if isinstance(parsed, (dict, list)):
        return parsed
    return None


def _text_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and item.get("type") in {"text", "output_text"}:
                parts.append(str(item.get("text", "")))
        return "\n".join(parts)
    return ""


def _normalize_name(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def _deduplicate(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    seen: set[str] = set()
    for candidate in candidates:
        try:
            marker = json.dumps(candidate, sort_keys=True, default=str)
        except TypeError:
            marker = repr(candidate)
        if marker not in seen:
            seen.add(marker)
            output.append(candidate)
    return output
