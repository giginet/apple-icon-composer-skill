# icon-composer-mcp

A personal [Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins) hosting the **icon-composer** plugin — tools to create and validate Apple [Icon Composer](https://developer.apple.com/icon-composer/) `.icon` packages.

## Install

From any Claude Code session:

```
/plugin marketplace add giginet/icon-composer-mcp
/plugin install icon-composer@icon-composer-dev
```

Local development (point the marketplace at a checkout instead of GitHub):

```
/plugin marketplace add /Users/giginet/work/Swift/icon-composer-mcp
/plugin install icon-composer@icon-composer-dev
```

The marketplace is named `icon-composer-dev` in `.claude-plugin/marketplace.json`; the `@icon-composer-dev` suffix disambiguates the plugin if you have multiple marketplaces installed.

## Skills

Once installed, two skills are available:

| Skill | Triggers on | What it does |
|---|---|---|
| `/icon-composer:create` | "make an icon", "create .icon", authoring any icon.json property | Writes a `.icon` package from an `icon.json` document plus image asset files. Validates against the schema before writing and checks every `image-name` has a matching `--asset`. |
| `/icon-composer:validate` | "check this icon", "why won't Icon Composer open this" | Runs `jsonschema` against `icon.json`, cross-checks referenced assets against `Assets/` on disk, and explains failures in terms of the schema. |

Both skills shell out to small Python CLIs bundled with the plugin and managed with [uv](https://docs.astral.sh/uv/). Each skill's preflight stops with an error if `uv` is not on `PATH`.

## Repo layout

```
.
├── .claude-plugin/
│   └── marketplace.json                 marketplace index (points at plugins/)
├── plugins/
│   └── icon-composer/
│       ├── .claude-plugin/plugin.json
│       ├── skills/
│       │   ├── create/SKILL.md
│       │   └── validate/SKILL.md
│       ├── scripts/
│       │   ├── create_icon.py
│       │   └── validate_icon.py
│       ├── tests/                       pytest suite for both scripts
│       ├── icon-schema.json             source of truth for icon.json
│       ├── pyproject.toml               uv-managed deps: jsonschema, pillow, pytest (dev)
│       └── uv.lock
├── fixtures/                            example .icon packages — simple-image, variables-changed, complex-icon, test-generated, plugin-test
└── README.md
```

## Hacking on the plugin locally

```sh
cd plugins/icon-composer
uv sync                          # installs runtime + dev (pytest) dependencies

# Run the unit tests
uv run pytest

# Validate every example fixture by hand
for f in ../../fixtures/*.icon; do
    uv run python scripts/validate_icon.py "$f"
done

# Round-trip: copy a fixture through the create CLI and re-validate
uv run python scripts/create_icon.py \
    --output /tmp/smoke.icon \
    --icon ../../fixtures/simple-image.icon/icon.json \
    --asset video.fill.png=../../fixtures/simple-image.icon/Assets/video.fill.png \
    --force
uv run python scripts/validate_icon.py /tmp/smoke.icon
```

`icon-schema.json` is the authoritative definition of the `icon.json` format — including per-appearance `-specializations` overrides, the LiquidGlass property set on groups, and the enum values Icon Composer's UI labels quietly map to (for example, Shadow `"Natural"` → `"neutral"`, `"Chromatic"` → `"layer-color"`).

## History

The project started as a Swift MCP server (see git history prior to this README rewrite). It was reduced to this plugin form because managing JSON files and invoking `jsonschema` doesn't need a long-lived process.
