# Icon Composer Skill

[![CI](https://github.com/giginet/apple-icon-composer-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/giginet/apple-icon-composer-skill/actions/workflows/ci.yml)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757?logo=anthropic&logoColor=white)](#claude-code)
[![Codex](https://img.shields.io/badge/Codex-plugin-10A37F?logo=openai&logoColor=white)](#codex)
[![gh skill](https://img.shields.io/badge/gh_skill-install-1F2328?logo=github&logoColor=white)](#github-cli-gh-skill)

The **icon-composer** plugin — tools to create and validate Apple [Icon Composer](https://developer.apple.com/icon-composer/) `.icon` packages. The same package installs three ways: as a [Claude Code plugin](https://docs.claude.com/en/docs/claude-code/plugins), a [Codex plugin](https://developers.openai.com/codex/plugins), or a standalone skill via [`gh skill`](https://cli.github.com/manual/gh_skill_install).

## Install

Published at <https://github.com/giginet/apple-icon-composer-skill>. Pick the host you use — each path installs the same two skills.

**Prerequisite:** [uv](https://docs.astral.sh/uv/) on your `PATH` (the skills run their bundled Python CLIs through it) — `brew install uv`.

### Claude Code

```
/plugin marketplace add giginet/apple-icon-composer-skill
/plugin install icon-composer@icon-composer
```

Then run `/reload-plugins` once and confirm with `/` — you should see `/icon-composer:authoring` and `/icon-composer:validate`. The `@icon-composer` suffix names the marketplace declared in `.claude-plugin/marketplace.json`, disambiguating it from any other marketplaces you have installed.

### Codex

```sh
codex plugin marketplace add giginet/apple-icon-composer-skill
# then open the plugin directory in Codex, pick the "Icon Composer" marketplace, and install
```

Backed by the repo marketplace at `.agents/plugins/marketplace.json` with the manifest at `plugins/icon-composer/.codex-plugin/plugin.json`. Codex sets `CLAUDE_PLUGIN_ROOT` for compatibility, so the bundled `${CLAUDE_PLUGIN_ROOT}/scripts/...` references work unchanged.

### GitHub CLI (`gh skill`)

Requires GitHub CLI v2.90.0+.

```sh
# Browse and pick interactively
gh skill install giginet/apple-icon-composer-skill

# Or install a specific skill for a given host
gh skill install giginet/apple-icon-composer-skill authoring --agent claude-code
gh skill install giginet/apple-icon-composer-skill validate --agent claude-code
```

> [!NOTE]
> `gh skill` copies only the skill directory (`SKILL.md`). The bundled Python CLIs (`create_icon.py`, `validate_icon.py`) and `icon-schema.json` live at the plugin root, so the full create/validate workflow needs the Claude Code or Codex plugin install above. Use `gh skill` when you want the skill instructions on another agent host.

## Skills

Once installed, two skills are available:

| Skill | Triggers on | What it does |
|---|---|---|
| `/icon-composer:authoring` | "make an icon", "change the icon's dark-mode color", authoring or editing any `icon.json` property | Either creates a fresh `.icon` via the bundled `create_icon.py` CLI, or edits an existing `icon.json` in place and re-validates. Covers all schema categories — fills, blend modes, shadows, translucency, LiquidGlass, layouts, specializations. |
| `/icon-composer:validate` | "check this icon", "why won't Icon Composer open this" | Runs `jsonschema` against `icon.json`, cross-checks referenced assets against `Assets/` on disk, and explains failures in terms of the schema. |

Both skills shell out to small Python CLIs bundled with the plugin and managed with [uv](https://docs.astral.sh/uv/). Each skill's preflight stops with an error if `uv` is not on `PATH`.

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
│       ├── skills/                      canonical skill sources (kept inside the plugin)
│       │   ├── authoring/SKILL.md
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

The canonical skill sources live **inside** `plugins/icon-composer/skills/` so that both the Claude Code and Codex plugins stay self-contained when a host copies the plugin directory. The top-level `skills` symlink points back into the plugin; `gh skill` discovers the skills remotely via the nested `plugins/icon-composer/skills/*/SKILL.md` path, so the symlink only matters for local `gh skill --from-local` runs.

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
