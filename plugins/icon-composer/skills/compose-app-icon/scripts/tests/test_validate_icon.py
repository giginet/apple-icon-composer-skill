from __future__ import annotations

import json
from pathlib import Path

import pytest

from validate_icon import main


# tests/ -> scripts -> compose-app-icon -> skills -> icon-composer -> plugins -> repo root
REPO_ROOT = Path(__file__).resolve().parents[6]
FIXTURES = REPO_ROOT / "fixtures"


@pytest.mark.parametrize(
    "name",
    [
        "simple-image",
        "variables-changed",
        "complex-icon",
        "test-generated",
        "scaled-layer",
    ],
)
def test_fixtures_are_valid(name: str, capsys: pytest.CaptureFixture[str]) -> None:
    exit_code = main([str(FIXTURES / f"{name}.icon")])
    out = capsys.readouterr().out
    assert exit_code == 0
    assert "VALID" in out


def test_accepts_bare_icon_json(capsys: pytest.CaptureFixture[str]) -> None:
    exit_code = main([str(FIXTURES / "simple-image.icon" / "icon.json")])
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_schema_violation_reports_exit_1(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    pkg = tmp_path / "bad.icon"
    pkg.mkdir()
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "x", "image-name": "x.png"}],
                        "shadow": {
                            "kind": "Natural",
                            "opacity": 0.5,
                        },  # UI label, not JSON
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )
    (pkg / "Assets").mkdir()
    (pkg / "Assets" / "x.png").write_bytes(b"\x89PNG\r\n\x1a\n")

    exit_code = main([str(pkg)])
    captured = capsys.readouterr().out
    assert exit_code == 1
    assert "INVALID" in captured
    assert "shadow" in captured


def _icon_with_position(tmp_path: Path, position: dict) -> Path:
    """Write a minimal valid .icon whose single layer carries the given position."""
    pkg = tmp_path / "positioned.icon"
    (pkg / "Assets").mkdir(parents=True)
    (pkg / "Assets" / "symbol.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [
                            {
                                "name": "symbol",
                                "image-name": "symbol.png",
                                "position": position,
                            }
                        ],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )
    return pkg


def test_scale_only_position_rejected(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    # Regression for #1: Icon Composer 1.5 cannot open a package whose position
    # has 'scale' but no 'translation-in-points', so the schema must reject it.
    exit_code = main([str(_icon_with_position(tmp_path, {"scale": 0.78}))])
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "INVALID" in out
    assert "translation-in-points" in out


def test_scale_with_translation_position_valid(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main(
        [
            str(
                _icon_with_position(
                    tmp_path, {"scale": 0.78, "translation-in-points": [0, 0]}
                )
            )
        ]
    )
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_missing_path_exits_2(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    exit_code = main([str(tmp_path / "does-not-exist.icon")])
    assert exit_code == 2


def test_referenced_asset_missing_on_disk(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    pkg = tmp_path / "missing-asset.icon"
    pkg.mkdir()
    (pkg / "Assets").mkdir()
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "x", "image-name": "missing.png"}],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )

    exit_code = main([str(pkg)])
    out = capsys.readouterr().out
    assert exit_code == 1
    assert "missing asset" in out
    assert "missing.png" in out


def test_skip_assets_bypasses_asset_check(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    pkg = tmp_path / "skip.icon"
    pkg.mkdir()
    (pkg / "Assets").mkdir()
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "x", "image-name": "missing.png"}],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )

    exit_code = main([str(pkg), "--skip-assets"])
    assert exit_code == 0
    assert "VALID" in capsys.readouterr().out


def test_orphaned_assets_emit_warning(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    pkg = tmp_path / "orphan.icon"
    pkg.mkdir()
    assets = pkg / "Assets"
    assets.mkdir()
    (assets / "used.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    (assets / "unused.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    (pkg / "icon.json").write_text(
        json.dumps(
            {
                "groups": [
                    {
                        "layers": [{"name": "x", "image-name": "used.png"}],
                        "shadow": {"kind": "neutral", "opacity": 0.5},
                        "translucency": {"enabled": True, "value": 0.5},
                    }
                ],
                "supported-platforms": {"squares": "shared"},
            }
        )
    )

    exit_code = main([str(pkg)])
    out = capsys.readouterr().out
    assert exit_code == 0
    assert "warning" in out
    assert "unused.png" in out
