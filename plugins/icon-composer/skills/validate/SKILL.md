---
name: validate
description: Validate an existing Apple Icon Composer `.icon` package (or standalone `icon.json`) against the bundled JSON Schema. Use this when the user wants to check an icon before shipping, diagnose a file that Icon Composer refuses to open, audit which properties are used, or confirm that every referenced asset exists on disk.
---

# Validate an Icon Composer `.icon` package

## Preflight: confirm `uv` is installed

Before running any commands from this skill, execute `which uv`. If it exits non-zero (no `uv` on PATH), stop and report the error to the user — this skill requires `uv`. Do not fall back to a system `python3`; the bundled `pyproject.toml` pins `requires-python = ">=3.9"` and dependency versions via `uv.lock`.

## Overview

This skill exposes a Python CLI at `${CLAUDE_PLUGIN_ROOT}/scripts/validate_icon.py` that:

1. Parses `icon.json` and checks it against `${CLAUDE_PLUGIN_ROOT}/icon-schema.json` using `jsonschema` (Draft 2020-12).
2. Reports every schema violation with a JSON pointer and the validator's message.
3. When pointed at a `.icon` directory, cross-checks every `image-name` and `image-name-specializations.value` against the files in `Assets/`, reporting both missing and orphaned files.

## Invocation

```bash
cd ${CLAUDE_PLUGIN_ROOT}
uv sync                                                   # once, to populate .venv
uv run python scripts/validate_icon.py /path/to/Foo.icon
# or, for a bare document:
uv run python scripts/validate_icon.py /path/to/icon.json
```

Flags:

| Flag | Meaning |
|---|---|
| _(positional)_ | Either a `.icon` directory or an `icon.json` file. |
| `--skip-assets` | Do not cross-check `image-name` references against `Assets/`. |

Exit codes: **0** = valid, **1** = schema or asset violation, **2** = bad input path.

## Reading the output

**Valid result:**

```
VALID: /path/to/Foo.icon/icon.json
```

A non-fatal warning may follow when some files in `Assets/` are not referenced by any layer:

```
warning: 2 unused asset(s) in Assets/: old-dark.png, old-light.png
```

**Schema errors** look like:

```
INVALID: /path/to/Foo.icon/icon.json (3 error(s))
  at /groups/0/layers/0
    Additional properties are not allowed ('fil' was unexpected)
  at /groups/0/shadow/kind
    'Natural' is not one of ['neutral', 'layer-color', 'none']
  at /groups/0/layers/1
    {'image-name-specializations': ...} is not valid under any of the given schemas
```

**Missing asset errors** look like:

```
INVALID: /path/to/Foo.icon has 1 missing asset(s)
  Assets/symbol-dark.png is referenced but not on disk
```

## Common failure patterns

Every message below is produced by `jsonschema` and maps back to a specific rule in `icon-schema.json`.

### `Additional properties are not allowed`

A top-level or nested key the schema does not recognize (typo, wrong case, or a UI label written as JSON). First suspects:

- `shadow.kind` set to `"Natural" / "Chromatic" / "Off"` — use `"neutral" / "layer-color" / "none"` instead.
- A layer-level key like `"ligthing"` or `"linear_gradient"` (typos / wrong casing).
- A `-specialization` (singular) array; the key is always `-specializations` plural.

### `'X' is not one of [...]` (enum mismatch)

Direct enum failure. Reference:

| Key | Valid values |
|---|---|
| `shadow.kind` | `"neutral"`, `"layer-color"`, `"none"` |
| `lighting` | `"individual"`, `"combined"` |
| `supported-platforms.squares` | `"shared"` |
| `color-space-for-untagged-svg-colors` | `"srgb"`, `"display-p3"` |
| `*.appearance` | `"light"`, `"dark"`, `"tinted"` |
| `blend-mode` | `normal, darken, multiply, plus-darker, lighten, screen, plus-lighter, overlay, soft-light, hard-light` |

### `is not valid under any of the given schemas`

The value for a `fill` object, a specialization `value`, or an `image-name` choice failed every branch of a `oneOf`/`anyOf`. Debug by checking:

- **fill** objects must have exactly one of `solid` / `automatic-gradient` / `linear-gradient`. Having both is invalid.
- **fill-specializations entries** allow `value` to be a fill object _or_ the literal string `"automatic"`.
- **layer** must contain either `image-name` (string) or `image-name-specializations` (array).

### `'X' is a required property`

A required field is missing. Common offenders:

- `groups` at top level, `supported-platforms` at top level.
- `name` on every layer.
- `shadow.kind` / `shadow.opacity` / `translucency.enabled` / `translucency.value` when the parent object is present.

## Gotchas checklist

When Icon Composer refuses to open a file the schema considers valid, the usual causes are:

- **UI label written as JSON.** Examples: `shadow.kind: "Natural"` instead of `"neutral"`. The schema catches these, but re-check after you fix the first error — Icon Composer fails fast on the first unknown value.
- **Identity `position`** (`scale: 1`, `translation-in-points: [0, 0]`) left in place. Icon Composer's save output omits them entirely.
- **Both `fill` and `fill-specializations`** on the same layer. Use one or the other; put a no-`appearance` entry in the specializations array for the light case.
- **Missing asset files** — every `image-name` and `image-name-specializations.value` must map to a file in `Assets/`. `validate_icon.py` reports these as a separate section after the schema check.
- **Canvas mismatch** — the schema does not check image dimensions, but Icon Composer is designed around 1024 × 1024 point assets. Smaller images render at their native size.

## Related skill

To author a fresh `.icon`, add a specialization to an existing one, or change any field of an existing `icon.json`, use the sibling skill `icon-composer:authoring`.
