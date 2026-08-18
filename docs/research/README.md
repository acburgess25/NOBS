# Research database

An inventory of every language, framework, library, model, and service NOBS
uses — why each one is here, where it is used, what to learn about it, and what
you would consider instead.

It exists for two readers:

- **You**, learning the stack. Read [`STACK.md`](STACK.md).
- **Coding agents**, which load [`stack.json`](stack.json) to find out what the
  project already standardises on before proposing new code.

## Files

| File | What it is |
|---|---|
| [`stack.json`](stack.json) | **Source of truth.** Structured, machine-readable, 38 entries. |
| [`STACK.md`](STACK.md) | Generated from the JSON for reading. Do not edit by hand. |
| [`COSTS.md`](COSTS.md) | What costs money and what does not. Short answer: only the Apple Developer Program. |
| [`../../scripts/build_stack_docs.py`](../../scripts/build_stack_docs.py) | Regenerates `STACK.md`. `--check` fails if it is stale. |

## Using it with an AI agent

Point the agent at `stack.json` before it writes code. A useful instruction:

> Read `docs/research/stack.json` first. Prefer a library that already has an
> entry over introducing a new one. If the task needs something absent from the
> file, check the `alternatives` on the closest entry, and respect the
> `constraints` list at the top.

The `constraints` array is the part that matters most: it encodes the rules a
dependency has to clear here — cross-platform, local-first, no dependency for
something the standard library already does — so an agent proposing a
macOS-only package or a cloud service knows it will be rejected before it
writes anything.

## What each entry holds

```json
{
  "id": "fastapi",
  "name": "FastAPI",
  "category": "web-framework",
  "layer": "backend",
  "declared": ">=0.115,<1",
  "resolved": "0.141.1",
  "role": "what it does here",
  "why_here": "why this one and not another",
  "used_in": ["app/main.py"],
  "docs": "https://fastapi.tiangolo.com/",
  "alternatives": [{"name": "Litestar", "when": "when it would be the better pick"}],
  "learn": "the thing that is genuinely worth knowing"
}
```

`declared` is the version constraint the project sets. `resolved` is what is
actually installed. They differ on purpose — the gap is where an upgrade lives.

## Updating it

Edit `stack.json`, then regenerate:

```bash
python3 scripts/build_stack_docs.py
```

Three tests in [`tests/test_stack_database.py`](../../tests/test_stack_database.py)
keep it from rotting:

1. every entry is well-formed and has a documentation link;
2. every dependency declared in `pyproject.toml` has an entry — add a
   dependency without documenting it and the suite fails;
3. `STACK.md` matches the JSON, so the generated page cannot drift.

## Exploring something new

`alternatives` is the starting point, not the answer. Before adopting anything
from it:

1. Check it against the `constraints` list — cross-platform and local-first
   rule out a lot of otherwise good options.
2. Prefer replacing a dependency over adding one alongside it.
3. Prototype behind an adapter if it is platform-specific.
4. Add the entry here as part of the same change, not afterwards.
