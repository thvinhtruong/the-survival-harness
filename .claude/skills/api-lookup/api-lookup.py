#!/usr/bin/env python3
"""Query the repo's OpenAPI 3 spec without loading it into context.

The spec is `API_SPEC` in .claude/harness.conf (repo-relative). Every command
prints a few lines of plain text instead of the file. An `x-auth` extension on
an operation, if the generator writes one, is printed beside the route.

  list [--prefix P] [--method M] [--tag T] [--auth SUBSTR]
  show METHOD PATH            one route, $refs expanded
  search TERM                 field name or schema name -> routes
  schema NAME                 one component schema, expanded
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
METHODS = ("get", "post", "put", "patch", "delete")
MAX_DEPTH = 4


def spec_path() -> Path:
    conf = ROOT / ".claude" / "harness.conf"
    text = conf.read_text() if conf.exists() else ""
    m = re.search(r"""^API_SPEC=["']?([^"'\s]*)""", text, re.M)
    if not m or not m.group(1):
        sys.exit("API_SPEC is not set in .claude/harness.conf")
    return ROOT / m.group(1)


def load() -> dict:
    path = spec_path()
    if not path.exists():
        sys.exit(f"{path} missing — regenerate it (the Doc map in CLAUDE.md names the command)")
    return json.loads(path.read_text())


def operations(doc: dict):
    for path, ops in doc["paths"].items():
        for method in METHODS:
            if method in ops:
                yield method, path, ops[method]


def auth(op: dict) -> str:
    return f"   [{op['x-auth']}]" if "x-auth" in op else ""


def ref_name(node: dict) -> str | None:
    ref = node.get("$ref")
    return ref.rsplit("/", 1)[-1] if ref else None


def resolve(doc: dict, node: dict) -> dict:
    name = ref_name(node)
    return doc["components"]["schemas"][name] if name else node


def type_of(doc: dict, node: dict) -> str:
    """One-line type label; the caller expands objects separately."""
    name = ref_name(node)
    if name:
        return name
    if "anyOf" in node or "oneOf" in node:
        return "|".join(type_of(doc, v) for v in node.get("anyOf") or node["oneOf"])
    if "enum" in node:
        return "|".join(json.dumps(v) for v in node["enum"])
    kind = node.get("type")
    if kind == "array":
        return type_of(doc, node.get("items", {})) + "[]"
    if kind == "object" and "additionalProperties" in node:
        inner = node["additionalProperties"]
        return f"map<{type_of(doc, inner) if isinstance(inner, dict) else 'any'}>"
    return kind or "any"


def expand(doc: dict, node: dict, out: list[str], indent: int = 2, seen=()) -> None:
    """Print an object schema's fields, following $refs with a cycle guard."""
    schema = resolve(doc, node)
    if schema.get("type") == "array":
        schema = resolve(doc, schema.get("items", {}))
    props = schema.get("properties")
    if not props:
        return
    required = set(schema.get("required", []))
    for field, prop in props.items():
        label = type_of(doc, prop)
        opt = "" if field in required else "?"
        out.append(f"{' ' * indent}{field}{opt}: {label}")
        if indent // 2 >= MAX_DEPTH:
            continue
        for child in _object_children(doc, prop):
            name = ref_name(child)
            if name and name in seen:
                out.append(f"{' ' * (indent + 2)}… {name} (above)")
                continue
            expand(doc, child, out, indent + 2, seen + ((name,) if name else ()))


def _object_children(doc: dict, prop: dict):
    """The sub-schemas of a property worth expanding (refs, arrays, unions)."""
    for node in [prop, *(prop.get("anyOf") or prop.get("oneOf") or [])]:
        if node is prop and (prop.get("anyOf") or prop.get("oneOf")):
            continue
        target = node.get("items", node) if node.get("type") == "array" else node
        if ref_name(target) or resolve(doc, target).get("properties"):
            yield target


def cmd_list(doc: dict, args: list[str]) -> None:
    def opt(flag: str) -> str | None:
        return args[args.index(flag) + 1].lower() if flag in args else None

    prefix, method, tag, auth_sub = opt("--prefix"), opt("--method"), opt("--tag"), opt("--auth")
    rows = []
    for m, path, op in operations(doc):
        if prefix and not path.startswith(prefix):
            continue
        if method and m != method:
            continue
        if tag and tag not in [t.lower() for t in op.get("tags", [])]:
            continue
        if auth_sub and auth_sub not in op.get("x-auth", "").lower():
            continue
        rows.append((m.upper(), path, op.get("x-auth", "")))
    width = max((len(f"{m} {p}") for m, p, _ in rows), default=0)
    for m, path, a in sorted(rows, key=lambda r: (r[1], r[0])):
        print(f"{f'{m} {path}':<{width}}  {a}".rstrip())
    print(f"\n{len(rows)} route(s)")


def cmd_show(doc: dict, args: list[str]) -> None:
    if len(args) < 2:
        sys.exit("usage: show METHOD PATH   (e.g. show GET /api/users/{id})")
    method, path = args[0].lower(), args[1]
    op = doc["paths"].get(path, {}).get(method)
    if op is None:
        matches = [f"{m.upper()} {p}" for m, p, _ in operations(doc) if path in p]
        sys.exit(f"no such route. did you mean: {', '.join(matches[:8]) or '(none)'}")

    out = [f"{method.upper()} {path}{auth(op)}"]
    out.append(f"tag: {', '.join(op.get('tags', [])) or '-'}   fn: {op.get('operationId', '-')}")
    if op.get("description"):
        out.append("  " + op["description"].strip().splitlines()[0])

    # An `authorization` header param repeats what x-auth / security already say.
    params = [p for p in op.get("parameters", []) if p.get("name", "").lower() != "authorization"]
    if params:
        out.append("params")
        for p in params:
            req = "" if p.get("required") else "?"
            out.append(f"  {p['name']}{req} ({p['in']}): {type_of(doc, p.get('schema', {}))}")

    body = op.get("requestBody")
    if body:
        node = next(iter(body["content"].values()))["schema"]
        out.append(f"request {type_of(doc, node)}")
        expand(doc, node, out, seen=(ref_name(node),))

    out.append("responses")
    for code, resp in op.get("responses", {}).items():
        content = resp.get("content", {})
        if not content:
            out.append(f"  {code} {resp.get('description', '')}")
            continue
        node = next(iter(content.values())).get("schema", {})
        out.append(f"  {code} {type_of(doc, node) if node else resp.get('description', '')}")
        # A framework-wide error envelope (e.g. FastAPI's 422) is named, not expanded.
        if code != "422":
            expand(doc, node, out, indent=4, seen=(ref_name(node),))
    print("\n".join(out))


def _schema_users(doc: dict, names: set[str]) -> set[str]:
    """Component schemas that reference any of `names`, transitively."""
    blob = {n: json.dumps(s) for n, s in doc["components"]["schemas"].items()}
    reach = set(names)
    changed = True
    while changed:
        changed = False
        for name, text in blob.items():
            if name in reach:
                continue
            if any(f'"#/components/schemas/{t}"' in text for t in reach):
                reach.add(name)
                changed = True
    return reach


def cmd_search(doc: dict, args: list[str]) -> None:
    term = args[0].lower()
    schemas = doc["components"]["schemas"]
    direct = {
        name
        for name, schema in schemas.items()
        if term in name.lower()
        or any(term in f.lower() for f in (schema.get("properties") or {}))
    }
    if not direct:
        sys.exit(f"no schema or field matching {term!r}")
    print("schemas: " + ", ".join(sorted(direct)))
    reach = _schema_users(doc, direct)
    for m, path, op in operations(doc):
        blob = json.dumps(op)
        if any(f'"#/components/schemas/{n}"' in blob for n in reach):
            print(f"  {m.upper()} {path}{auth(op)}")


def cmd_schema(doc: dict, args: list[str]) -> None:
    name = args[0]
    if name not in doc["components"]["schemas"]:
        near = [n for n in doc["components"]["schemas"] if name.lower() in n.lower()]
        sys.exit(f"unknown schema. near: {', '.join(near[:8]) or '(none)'}")
    out = [name]
    expand(doc, {"$ref": f"#/components/schemas/{name}"}, out, seen=(name,))
    print("\n".join(out))


def main() -> int:
    handlers = {"list": cmd_list, "show": cmd_show, "search": cmd_search, "schema": cmd_schema}
    if len(sys.argv) < 2 or sys.argv[1] not in handlers:
        print(__doc__)
        return 1
    handlers[sys.argv[1]](load(), sys.argv[2:])
    return 0


if __name__ == "__main__":
    sys.exit(main())
