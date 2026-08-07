"""Small, dependency-free JSON Schema validator for function-tool arguments.

The validator intentionally implements the JSON Schema features commonly emitted
by OpenAI-compatible tool definitions. Unknown annotation keywords are ignored.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class SchemaError:
    path: str
    message: str

    def __str__(self) -> str:
        return f"{self.path}: {self.message}"


def validate(instance: Any, schema: dict[str, Any]) -> list[SchemaError]:
    errors: list[SchemaError] = []
    _validate(instance, schema or {}, "$", schema or {}, errors)
    return errors


def _resolve_ref(ref: str, root: dict[str, Any]) -> dict[str, Any] | None:
    if not ref.startswith("#/"):
        return None
    value: Any = root
    for raw_part in ref[2:].split("/"):
        part = raw_part.replace("~1", "/").replace("~0", "~")
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value if isinstance(value, dict) else None


def _matches_type(value: Any, expected: str) -> bool:
    if expected == "null":
        return value is None
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "string":
        return isinstance(value, str)
    if expected == "array":
        return isinstance(value, list)
    if expected == "object":
        return isinstance(value, dict)
    return True


def _validate(
    value: Any,
    schema: Any,
    path: str,
    root: dict[str, Any],
    errors: list[SchemaError],
) -> None:
    if schema is True:
        return
    if schema is False:
        errors.append(SchemaError(path, "value is not allowed"))
        return
    if not isinstance(schema, dict):
        return

    if "$ref" in schema:
        resolved = _resolve_ref(str(schema["$ref"]), root)
        if resolved is None:
            errors.append(SchemaError(path, f"unresolvable schema reference {schema['$ref']!r}"))
            return
        _validate(value, resolved, path, root, errors)
        return

    if "allOf" in schema:
        for child in schema["allOf"]:
            _validate(value, child, path, root, errors)

    if "anyOf" in schema:
        if not any(not _collect(value, child, path, root) for child in schema["anyOf"]):
            errors.append(SchemaError(path, "does not match any allowed schema"))
            return

    if "oneOf" in schema:
        matches = sum(not _collect(value, child, path, root) for child in schema["oneOf"])
        if matches != 1:
            errors.append(SchemaError(path, f"must match exactly one schema; matched {matches}"))
            return

    if "not" in schema and not _collect(value, schema["not"], path, root):
        errors.append(SchemaError(path, "matches a forbidden schema"))
        return

    if "const" in schema and value != schema["const"]:
        errors.append(SchemaError(path, f"must equal {schema['const']!r}"))
    if "enum" in schema and value not in schema["enum"]:
        errors.append(SchemaError(path, f"must be one of {schema['enum']!r}"))

    expected = schema.get("type")
    if expected is not None:
        expected_types = [expected] if isinstance(expected, str) else list(expected)
        if not any(_matches_type(value, item) for item in expected_types):
            errors.append(
                SchemaError(path, f"expected {' or '.join(expected_types)}, got {type(value).__name__}")
            )
            return

    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                errors.append(SchemaError(path, f"missing required property {key!r}"))

        properties = schema.get("properties", {})
        pattern_properties = schema.get("patternProperties", {})
        matched: set[str] = set()
        for key, child in properties.items():
            if key in value:
                matched.add(key)
                _validate(value[key], child, f"{path}.{key}", root, errors)
        for key, item in value.items():
            for pattern, child in pattern_properties.items():
                if re.search(pattern, key):
                    matched.add(key)
                    _validate(item, child, f"{path}.{key}", root, errors)

        additional = schema.get("additionalProperties", True)
        for key, item in value.items():
            if key in matched:
                continue
            if additional is False:
                errors.append(SchemaError(f"{path}.{key}", "additional property is not allowed"))
            elif isinstance(additional, dict):
                _validate(item, additional, f"{path}.{key}", root, errors)

        if len(value) < schema.get("minProperties", 0):
            errors.append(SchemaError(path, "has too few properties"))
        if "maxProperties" in schema and len(value) > schema["maxProperties"]:
            errors.append(SchemaError(path, "has too many properties"))

    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errors.append(SchemaError(path, "has too few items"))
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(SchemaError(path, "has too many items"))
        if schema.get("uniqueItems"):
            seen: list[Any] = []
            for item in value:
                if item in seen:
                    errors.append(SchemaError(path, "items must be unique"))
                    break
                seen.append(item)
        prefix = schema.get("prefixItems", [])
        for index, child in enumerate(prefix):
            if index < len(value):
                _validate(value[index], child, f"{path}[{index}]", root, errors)
        items = schema.get("items")
        if isinstance(items, dict):
            start = len(prefix)
            for index, item in enumerate(value[start:], start=start):
                _validate(item, items, f"{path}[{index}]", root, errors)

    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            errors.append(SchemaError(path, "is shorter than minLength"))
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errors.append(SchemaError(path, "is longer than maxLength"))
        if "pattern" in schema and re.search(schema["pattern"], value) is None:
            errors.append(SchemaError(path, f"does not match pattern {schema['pattern']!r}"))

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(SchemaError(path, f"must be >= {schema['minimum']}"))
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(SchemaError(path, f"must be <= {schema['maximum']}"))
        if "exclusiveMinimum" in schema and value <= schema["exclusiveMinimum"]:
            errors.append(SchemaError(path, f"must be > {schema['exclusiveMinimum']}"))
        if "exclusiveMaximum" in schema and value >= schema["exclusiveMaximum"]:
            errors.append(SchemaError(path, f"must be < {schema['exclusiveMaximum']}"))


def _collect(
    value: Any, schema: Any, path: str, root: dict[str, Any]
) -> list[SchemaError]:
    collected: list[SchemaError] = []
    _validate(value, schema, path, root, collected)
    return collected
