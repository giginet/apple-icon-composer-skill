# icon-composer-mcp

A personal [Claude Code plugin marketplace](https://docs.claude.com/en/docs/claude-code/plugins) hosting the **icon-composer** plugin — tools to create and validate Apple [Icon Composer](https://developer.apple.com/icon-composer/) `.icon` packages.

## Install

This repo is published at <https://github.com/giginet/icon-composer-agent-skill>. The snippets below are all run inside a Claude Code session.

### From GitHub

```
/plugin marketplace add giginet/icon-composer-agent-skill
/plugin install icon-composer@icon-composer
```

### About the `@icon-composer` suffix

The marketplace is named `icon-composer` in `.claude-plugin/marketplace.json`; the `@icon-composer` after the plugin name disambiguates it from any other marketplaces you have installed.

### After install

Run `/reload-plugins` once so Claude Code picks up the new skills. You can confirm they are active by typing `/` and looking for `/icon-composer:authoring` and `/icon-composer:validate` in the list.

### With the GitHub CLI (`gh skill`)

The skills are also published at the top-level `skills/` directory, so they can be installed directly with [`gh skill`](https://cli.github.com/manual/gh_skill_install) (GitHub CLI v2.90.0+):

```sh
# Browse and pick interactively
gh skill install giginet/icon-composer-agent-skill

# Or install a specific skill for Claude Code
gh skill install giginet/icon-composer-agent-skill authoring --agent claude-code
gh skill install giginet/icon-composer-agent-skill validate --agent claude-code
```

> [!NOTE]
> `gh skill` copies only the skill directory (`SKILL.md`). The bundled Python CLIs (`create_icon.py`, `validate_icon.py`) and `icon-schema.json` live at the plugin root and are referenced via `${CLAUDE_PLUGIN_ROOT}`, so the full create/validate workflow still requires the plugin install above. Use `gh skill` when you want the skill instructions on a non-marketplace agent host.

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
│   └── marketplace.json                 marketplace index (points at plugins/)
├── skills/                              canonical skill sources (top-level for `gh skill install`)
│   ├── authoring/SKILL.md
│   └── validate/SKILL.md
├── plugins/
│   └── icon-composer/
│       ├── .claude-plugin/plugin.json
│       ├── skills -> ../../skills       symlink so Claude Code loads the same skills
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
