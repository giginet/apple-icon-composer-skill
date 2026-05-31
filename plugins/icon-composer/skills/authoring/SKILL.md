---
name: authoring
description: Author an Apple Icon Composer `.icon` package — either by creating a new one from scratch or by editing an existing one in place. Use this when the user asks to generate an app icon, scaffold a `.icon` from parameters, set up light/dark/tinted appearance variants (specializations), or change any field of an existing `icon.json` — fills, blend modes, shadows, translucency, LiquidGlass Mode/Specular/Blur, layer layouts, or asset filenames.
---

# Author an Icon Composer `.icon` package

## Preflight: confirm `uv` is installed

Before running any commands from this skill, execute `which uv`. If it exits non-zero (no `uv` on PATH), stop and report the error to the user — this skill requires `uv`. Do not fall back to a system `python3`; the bundled `pyproject.toml` pins `requires-python = ">=3.9"` and dependency versions via `uv.lock`.

## Overview

A `.icon` is a directory (macOS document package) containing a declarative `icon.json` and an `Assets/` folder. This skill covers both workflows:

- **Create** a new `.icon` from an `icon.json` document and asset files using the bundled `${CLAUDE_PLUGIN_ROOT}/scripts/create_icon.py` CLI, which validates against `icon-schema.json` before writing and checks every referenced `image-name` against the supplied `--asset` map.
- **Edit** an existing `.icon` in place by rewriting `icon.json` directly with the Edit tool and re-running `${CLAUDE_PLUGIN_ROOT}/scripts/validate_icon.py` (provided by the sibling `icon-composer:validate` skill). Asset file changes happen by replacing files inside `Assets/` on disk.

## Creating a new `.icon`

```bash
cd ${CLAUDE_PLUGIN_ROOT}
uv sync                                               # once, to populate .venv
uv run python scripts/create_icon.py \
    --output /path/to/Foo.icon \
    --icon /path/to/icon.json \
    --asset star.png=/path/to/star.png \
    --asset ring.png=/path/to/ring.png
```

Flags:

| Flag | Meaning |
|---|---|
| `--output PATH` | Target `.icon` directory (must end with `.icon`). |
| `--icon PATH` | `icon.json` document, or `-` to read the JSON from stdin. |
| `--asset NAME=PATH` | Register one image asset. Repeat for each `image-name` referenced in the document. `NAME` is the filename inside `Assets/`; `PATH` is the source file on disk. |
| `--force` | Overwrite `--output` if it already exists. |
| `--no-validate` | Skip JSON Schema validation (rarely what you want). |

## Editing an existing `.icon`

There is no `update` subcommand. Because `icon.json` is just JSON and the schema is well-defined, edit the file in place with the Edit tool and then re-validate:

1. `Read` the current `<pkg>.icon/icon.json` to see what's there.
2. Use the `Edit` tool to change exactly the field(s) the user asked about — a color string, a blend-mode enum, a `position.scale`, a specialization entry, etc. Refer to the schema sections below for allowed values.
3. If an asset image needs to change, overwrite the file in `<pkg>.icon/Assets/` (same filename → no `image-name` edit needed; new filename → update every `image-name` / `image-name-specializations.value` that referenced the old name and place the new asset in `Assets/`).
4. Run the validator on the whole package so both the schema and the asset-reference cross-check pass:

    ```bash
    cd ${CLAUDE_PLUGIN_ROOT}
    uv run python scripts/validate_icon.py /path/to/Foo.icon
    ```

5. If validation fails, the `icon-composer:validate` skill explains how to read the output.

Prefer minimal, targeted edits — keep keys in their existing order, don't reformat the file, and only add a `-specializations` array when the user actually wants a per-appearance override. The `create_icon.py` CLI's output format (`sort_keys=True`, 2-space indent) is the target style if the file is being re-written wholesale.

## Canvas and asset sizing

Icon Composer's design canvas is **1024 × 1024 points**. Image assets should be 1024 × 1024 PNG (or SVG) with the visible content centered; `position.translation-in-points` operates in this 1024-point coordinate system, so `[0, 0]` means no offset from the canvas center. Smaller assets render at their native size and look visually smaller than the canvas.

## `icon.json` — top-level shape

```jsonc
{
  "color-space-for-untagged-svg-colors": "display-p3",   // optional: "srgb" | "display-p3"
  "fill": { ... },                                        // OR fill-specializations (background)
  "fill-specializations": [ ... ],                        // per-appearance background fill
  "groups": [ ... ],                                      // REQUIRED: ordered layer groups
  "supported-platforms": { "squares": "shared" }          // REQUIRED
}
```

### Groups — one record per LiquidGlass-rendered bundle

A group shares the same LiquidGlass rendering pipeline across its layers and carries these properties (each with an optional sibling `<key>-specializations`):

| JSON key | Type | UI label | Notes |
|---|---|---|---|
| `lighting` | `"individual"` \| `"combined"` | **Mode** | How light interacts per-layer or across the group. |
| `specular` | boolean | **Specular** | Highlight on/off. |
| `blur` | number 0–1 | **Blur** | Background blur amount. |
| `translucency` | `{ enabled: bool, value: number }` | Translucency | |
| `shadow` | `{ kind: string, opacity: number }` | Shadow | See the UI ↔ JSON table below. |
| `position` | `{ scale?: number, translation-in-points?: [x, y] }` | Composition.Layout | Omit when identity. |

### Layers — image-backed records inside a group

| JSON key | Type | Category | Notes |
|---|---|---|---|
| `name` | string | — | **Required** display name. |
| `image-name` | string | Composition.Layout | Filename in `Assets/`. Required unless `image-name-specializations` is present. |
| `image-name-specializations` | array | Composition.Layout | Per-appearance filenames. |
| `fill` | fill object | Color | See Fill below. |
| `fill-specializations` | array | Color | |
| `blend-mode` | string | Color | Enum: `normal, darken, multiply, plus-darker, lighten, screen, plus-lighter, overlay, soft-light, hard-light`. |
| `blend-mode-specializations` | array | Color | |
| `opacity` | number 0–1 | Color | |
| `opacity-specializations` | array | Color | |
| `glass` | boolean | Effects | LiquidGlass on/off for this layer (not the same as group-level `specular`). |
| `glass-specializations` | array | Effects | |
| `hidden` | boolean | Composition.Visible | |
| `hidden-specializations` | array | Composition.Visible | |
| `position` | position object | Composition.Layout | |
| `position-specializations` | array | Composition.Layout | |

### Fill — three alternative shapes

```jsonc
{ "solid":              "extended-srgb:1.0,1.0,1.0,1.0" }
{ "automatic-gradient": "extended-srgb:0.0,0.5,1.0,1.0" }
{ "linear-gradient":   ["extended-srgb:...", "extended-srgb:..."] }
```

Color strings are `<colorspace>:<comp1>,<comp2>,...`. Common spaces: `extended-srgb`, `display-p3`, `extended-gray`.

## Specializations — per-appearance overrides

Icon Composer supports three appearances: **light** (default), **dark**, **tinted**. Any specializable property `X` has an optional sibling array `X-specializations`:

```jsonc
"fill-specializations": [
  { "value": { "automatic-gradient": "extended-srgb:0,0.53,1,1" } }, // omitting appearance = default/light
  { "appearance": "dark",   "value": { "linear-gradient": [ "...", "..." ] } },
  { "appearance": "tinted", "value": "automatic" }                    // inherit default
]
```

- Omitting `appearance` usually targets **light**, but `"light"` may also be set explicitly.
- `value` may be the literal string `"automatic"` to inherit the default appearance's value.

Specializations exist for exactly these properties:

- **Color**: `fill`, `blend-mode`, `opacity`
- **LiquidGlass** (group): `lighting`, `specular`, `blur`, `translucency`, `shadow` (plus the nested keys `translucency.enabled` / `translucency.value` / `shadow.kind` / `shadow.opacity`)
- **Effects** (layer): `glass`
- **Composition.Visible** (layer): `hidden`
- **Composition.Layout** (layer & group): `image-name`, `position`

## UI ↔ JSON label mapping

Several Icon Composer UI labels differ from the JSON keys they write.

| UI | JSON |
|---|---|
| Shadow: **Natural** | `shadow.kind: "neutral"` |
| Shadow: **Chromatic** | `shadow.kind: "layer-color"` |
| Shadow: **Off** | `shadow.kind: "none"` |
| Blend Mode: **Plus Darker** | `"plus-darker"` |
| Blend Mode: **Plus Lighter** | `"plus-lighter"` |
| Blend Mode: **Soft / Hard Light** | `"soft-light"` / `"hard-light"` |
| LiquidGlass: **Mode** | `lighting` |

Blend modes are otherwise the UI label lower-cased and kebab-cased.

## Minimal example

```bash
# Compose the icon document
cat > /tmp/icon.json <<'JSON'
{
  "fill": { "automatic-gradient": "extended-srgb:0.20,0.50,1.00,1.00" },
  "groups": [{
    "layers": [
      { "name": "symbol", "image-name": "symbol.png", "glass": true }
    ],
    "shadow": { "kind": "neutral", "opacity": 0.5 },
    "translucency": { "enabled": true, "value": 0.5 }
  }],
  "supported-platforms": { "squares": "shared" }
}
JSON

uv run python scripts/create_icon.py \
    --output /tmp/Hello.icon \
    --icon /tmp/icon.json \
    --asset symbol.png=/path/to/symbol-1024.png
```

## Dark-mode specialization example

```jsonc
// icon.json snippet: same layer, ring is cream in light, gradient in dark
{
  "name": "ring",
  "image-name": "ring.png",
  "fill-specializations": [
    { "value": { "solid": "extended-srgb:1.00,0.95,0.70,1.00" } },
    { "appearance": "dark",
      "value": { "linear-gradient": [
        "extended-srgb:0.95,0.30,0.60,1",
        "extended-srgb:0.40,0.20,0.80,1"
      ] } }
  ]
}
```

## Shortcut: list every asset referenced by a document

```bash
jq -r '
  [
    .groups[].layers[]
    | (."image-name"? // empty),
      (."image-name-specializations"? // [] | .[] | .value)
  ]
  | unique[]
' /path/to/icon.json
```

Use this to build the `--asset` flags for `create_icon.py` when retrofitting an existing document.

## Gotchas when authoring for Icon Composer

- Use JSON values, not UI labels (`"neutral"` not `"Natural"`, `"layer-color"` not `"Chromatic"`).
- Do not emit `position` blocks with identity values (`scale: 1`, `translation-in-points: [0, 0]`) — Icon Composer's own save output omits them.
- On a single layer, use either `fill` _or_ `fill-specializations`, not both. The same pattern holds for the other `X`/`X-specializations` pairs: put a no-`appearance` entry in the specializations array for the light case.
- Every `image-name` (and every `image-name-specializations.value`) must map to a file supplied via `--asset`.
