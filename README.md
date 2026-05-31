# Icon Composer Skill

[![CI](https://github.com/giginet/apple-icon-composer-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/giginet/apple-icon-composer-skill/actions/workflows/ci.yml)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757?logo=anthropic&logoColor=white)](#claude-code)
[![Codex](https://img.shields.io/badge/Codex-plugin-10A37F?logo=openai&logoColor=white)](#codex)
[![gh skill](https://img.shields.io/badge/gh_skill-install-1F2328?logo=github&logoColor=white)](#github-cli-gh-skill)

The **icon-composer** plugin — tools to create, validate, and render Apple [Icon Composer](https://developer.apple.com/icon-composer/) `.icon` packages. The same package installs three ways: as a [Claude Code plugin](https://docs.claude.com/en/docs/claude-code/plugins), a [Codex plugin](https://developers.openai.com/codex/plugins), or a standalone skill via [`gh skill`](https://cli.github.com/manual/gh_skill_install).

## Install

Published at <https://github.com/giginet/apple-icon-composer-skill>. Pick the host you use — each path installs the same `compose-app-icon` skill.

**Prerequisite:** [uv](https://docs.astral.sh/uv/) on your `PATH` (the skill runs its bundled Python CLIs through it) — `brew install uv`.

### Claude Code

```
/plugin marketplace add giginet/apple-icon-composer-skill
/plugin install icon-composer@icon-composer
```

Then run `/reload-plugins` once and confirm with `/` — you should see `/icon-composer:compose-app-icon`. The `@icon-composer` suffix names the marketplace declared in `.claude-plugin/marketplace.json`, disambiguating it from any other marketplaces you have installed.

### Codex

```sh
codex plugin marketplace add giginet/apple-icon-composer-skill
# then open the plugin directory in Codex, pick the "Icon Composer" marketplace, and install
```

Backed by the repo marketplace at `.agents/plugins/marketplace.json` with the manifest at `plugins/icon-composer/.codex-plugin/plugin.json`. Codex sets `CLAUDE_PLUGIN_ROOT` for compatibility, so the skill's `${CLAUDE_PLUGIN_ROOT}/skills/compose-app-icon/scripts/...` references work unchanged.

### GitHub CLI (`gh skill`)

Requires GitHub CLI v2.90.0+.

```sh
# Browse and pick interactively
gh skill install giginet/apple-icon-composer-skill

# Or install it directly for a given host
gh skill install giginet/apple-icon-composer-skill compose-app-icon --agent claude-code
```

The skill is self-contained: its `scripts/` directory is a `uv` project bundling `create_icon.py`, `validate_icon.py`, `icon-schema.json`, and `uv.lock`, so `gh skill` copies the whole working toolset — not just the instructions. Outside a plugin host, `${CLAUDE_PLUGIN_ROOT}` is unset, so run the CLIs from the installed skill's `scripts/` directory (the `SKILL.md` explains this); `uv` is still required.

## Skill

One skill, `compose-app-icon`, covers authoring, validation, and rendering:

| Triggers on | What it does |
|---|---|
| "make an icon", "change the icon's dark-mode color", authoring or editing any `icon.json` property | Creates a fresh `.icon` via the bundled `create_icon.py` CLI, or edits an existing `icon.json` in place and re-validates. Covers all schema categories — fills, blend modes, shadows, translucency, LiquidGlass, layouts, specializations. |
| "check this icon", "why won't Icon Composer open this" | Runs `jsonschema` against `icon.json` via `validate_icon.py`, cross-checks referenced assets against `Assets/` on disk, and explains failures in terms of the schema. |
| "render this icon", "show me the dark/tinted variant", "does Icon Composer actually open this" | On macOS with Xcode, renders any platform/appearance to a PNG with `ictool` (bundled in `Icon Composer.app`, located via `xcode-select -p`). A failed render is the ground-truth signal that Icon Composer can't open the package — catching engine-level issues the schema can't, like the scale-only `position` bug. |

The skill shells out to two small Python CLIs bundled in its `scripts/` directory (a [uv](https://docs.astral.sh/uv/) project); its preflight stops with an error if `uv` is not on `PATH`. The optional `ictool` rendering/ground-truth step needs macOS with Xcode (Icon Composer 1.5+) and is skipped elsewhere — `validate_icon.py` is the portable check.

## Repo layout

```
.
├── .claude-plugin/
│   └── marketplace.json                 Claude Code marketplace index (points at plugins/)
├── .agents/plugins/
│   └── marketplace.json                 Codex repo marketplace (points at plugins/)
├── skills -> plugins/icon-composer/skills   symlink for top-level `gh skill --from-local`
├── plugins/
│   └── icon-composer/
│       ├── .claude-plugin/plugin.json   Claude Code manifest
│       ├── .codex-plugin/plugin.json    Codex manifest (skills: "./skills/")
│       └── skills/
│           └── compose-app-icon/
│               ├── SKILL.md             authoring + validation instructions
│               └── scripts/             self-contained uv project
│                   ├── create_icon.py
│                   ├── validate_icon.py
│                   ├── icon-schema.json source of truth for icon.json
│                   ├── pyproject.toml   uv-managed deps: jsonschema, pillow, pytest (dev)
│                   ├── uv.lock
│                   └── tests/           pytest suite for both CLIs
├── fixtures/                            example .icon packages — simple-image, variables-changed, complex-icon, test-generated, plugin-test
└── README.md
```

The skill is self-contained: the CLIs, schema, and their `uv` project all live in `plugins/icon-composer/skills/compose-app-icon/scripts/`, so every host — Claude Code, Codex, or `gh skill` — gets the full toolset when it copies the skill directory, with no shared files outside it. The top-level `skills` symlink points back into the plugin for local `gh skill --from-local` runs; remote `gh skill` discovers the skill via the nested `plugins/icon-composer/skills/*/SKILL.md` path.

## Hacking on the skill locally

```sh
cd plugins/icon-composer/skills/compose-app-icon/scripts
uv sync                          # installs runtime + dev (pytest) dependencies

# Run the unit tests
uv run pytest

# Validate every example fixture by hand
for f in ../../../../../fixtures/*.icon; do
    uv run python validate_icon.py "$f"
done

# Round-trip: copy a fixture through the create CLI and re-validate
FIX=../../../../../fixtures/simple-image.icon
uv run python create_icon.py \
    --output /tmp/smoke.icon \
    --icon "$FIX/icon.json" \
    --asset video.fill.png="$FIX/Assets/video.fill.png" \
    --force
uv run python validate_icon.py /tmp/smoke.icon
```

`icon-schema.json` is the authoritative definition of the `icon.json` format — including per-appearance `-specializations` overrides, the LiquidGlass property set on groups, and the enum values Icon Composer's UI labels quietly map to (for example, Shadow `"Natural"` → `"neutral"`, `"Chromatic"` → `"layer-color"`).
