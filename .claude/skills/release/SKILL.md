---
name: release
description: Cut a new version of the icon-composer plugin — bump the version across every manifest, relock, verify the CI gate locally, commit to main, and publish a GitHub release. Use this when the user asks to release, ship, cut, or tag a version ("release 1.2", "バージョン1.2を出して", "tag a new version", "publish a release").
---

# Release a new version

This repo ships a Claude Code / Codex plugin. A release is: bump the version in
every manifest, relock, verify, commit to `main`, then create a GitHub release
whose tag `gh` creates for you.

There is no CHANGELOG file — release notes are generated from merged PR titles,
so nothing needs to be hand-written.

## 1. Decide the version

Ask the user if they did not say. Otherwise infer from what landed since the last
tag:

```bash
git fetch origin --tags
git log --oneline $(git describe --tags --abbrev=0)..origin/main
```

Tags are `vX.Y.Z` (lightweight, created by `gh release create`). Normalize a
shorthand like "1.2" to the full `1.2.0` — every existing tag is three-part.

## 2. Preflight

```bash
git switch main && git pull --ff-only
git status --short   # must be empty
```

Do not start from a dirty tree or a stale `main`. If the release is for a PR the
user just merged, confirm the merge commit is present in `git log`.

## 3. Bump the version

Find every file carrying the **current** version — do not trust a hardcoded list,
manifests get added:

```bash
grep -rn "<current-version>" --include="*.json" --include="*.toml" --include="*.lock" .
```

As of 1.2.0 that is four files:

| File | How to update |
|---|---|
| `plugins/icon-composer/.claude-plugin/plugin.json` | edit `"version"` |
| `plugins/icon-composer/.codex-plugin/plugin.json` | edit `"version"` |
| `plugins/icon-composer/skills/compose-app-icon/scripts/pyproject.toml` | edit `version = ` |
| `plugins/icon-composer/skills/compose-app-icon/scripts/uv.lock` | **never hand-edit** — see below |

`.claude-plugin/marketplace.json` (repo root) carries no version. Leave it alone.

Regenerate the lock instead of editing it:

```bash
cd plugins/icon-composer/skills/compose-app-icon/scripts && uv lock
```

Then inspect the diff. `pyproject.toml` sets `exclude-newer = "1 week"`, which is
relative to *now*, so `uv lock` always rewrites the `exclude-newer` timestamp:

```bash
git diff plugins/icon-composer/skills/compose-app-icon/scripts/uv.lock
```

Expect exactly two changed lines — the project `version` and `exclude-newer`. If
dependency versions also moved, that is a real dependency upgrade riding along:
say so to the user and make sure step 4 passes before deciding to keep it.

## 4. Run the CI gate locally

`.github/workflows/ci.yml` runs these four steps. Run all of them from the
`scripts/` directory before pushing — CI on `main` is post-hoc, so a red build is
a broken release:

```bash
cd plugins/icon-composer/skills/compose-app-icon/scripts
uv sync --locked          # fails if step 3 left the lock out of sync
uv run pytest
uv run ruff check .
uv run ruff format --check .
uv run ty check
```

## 5. Commit to `main`

Version bumps go **directly on `main`** — that is the established convention here
(`bb92545`, `f2efe76`), not a PR. Commit message in English, subject
`Bump version to X.Y.Z`, with a body saying what the release contains and which
PR/issue it came from.

```bash
git add -A plugins
git commit   # subject: Bump version to X.Y.Z
git push origin main
```

End the message with the `Co-Authored-By:` trailer for the model you are running as.

## 6. Publish the release

`gh` creates the tag from `--target`, so do not `git tag` by hand:

```bash
gh release create vX.Y.Z --target main --title vX.Y.Z --generate-notes
```

`--generate-notes` produces the "What's Changed" PR list, "New Contributors", and
the compare link — matching every prior release.

## 7. Verify and report

```bash
gh release view vX.Y.Z
gh run list --limit 2   # the bump commit's CI run must be success
```

Report the release URL to the user, plus the CI result. If CI went red after the
push, say so plainly rather than presenting the release as clean.

## Notes

- Fork PRs need workflow approval, so their checks may show as "no checks
  reported" until approved. Verify the merge commit's own run on `main` instead.
- Releases are public and the tag is hard to retract — get the version number
  confirmed before step 5, not after.
