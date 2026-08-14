#!/usr/bin/env python3
"""Lightweight packaging-only validator for the Potato Figure Audit skill.

This intentionally does not inspect scientific or visual audit behavior. It
checks portable Skill metadata and, optionally, a ZIP produced from the Skill.
"""

from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path


SKILL_NAME = "potato-figure-audit"
VERSION = "0.4.3-alpha"
TEXT_SUFFIXES = {".md", ".yaml", ".yml", ".tsv", ".txt", ".R", ".py", ".json"}
FORBIDDEN_FILE_RE = re.compile(
    r"(^\.Rhistory$|^\.RData$|__pycache__|\.pyc$|\.tmp$|\.bak$|\.swp$|"
    r"^\.DS_Store$|^Thumbs\.db$|^desktop\.ini$|^\.env(?:\.|$)|"
    r"(?:^|[/\\])(auth\.json|credentials?|private[_ -]?key)(?:$|[.])$)", re.I
)
ABSOLUTE_PATH_RE = re.compile(
    r"(?<![A-Za-z0-9])(?:[A-Za-z]:[\\/]|/(?:home|mnt|Users|tmp)(?:/|$))", re.I
)
SECRET_RE = re.compile(
    r"(?:BEGIN (?:RSA |OPENSSH )?PRIVATE KEY|(?:api[_ -]?key|password|secret|token)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,})",
    re.I,
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    try:
        end = next(i for i, line in enumerate(lines[1:], 1) if line.strip() == "---")
    except StopIteration:
        return {}
    result: dict[str, str] = {}
    current: str | None = None
    for line in lines[1:end]:
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            current, value = match.groups()
            result[current] = value.strip().strip('"\'')
        elif current and line.startswith((" ", "\t")):
            result[current] = (result[current] + " " + line.strip()).strip()
    return result


def manifest_fields(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.lstrip("\ufeff").splitlines():
        match = re.match(r"^(name|version|license):\s*(.*?)\s*$", line)
        if match:
            out[match.group(1)] = match.group(2).strip().strip('"\'')
    return out


def check_zip(path: Path) -> list[str]:
    failures: list[str] = []
    with zipfile.ZipFile(path) as archive:
        names = [info.filename for info in archive.infolist()]
        roots = {name.split("/", 1)[0] for name in names if name and not name.startswith("/")}
        if roots != {SKILL_NAME}:
            failures.append(f"ZIP_ROOT_COUNT/NAME invalid: {sorted(roots)!r}")
        for name in names:
            p = Path(name)
            if "\\" in name:
                failures.append(f"backslash entry: {name}")
            if name.startswith("/") or re.match(r"^[A-Za-z]:[\\/]", name):
                failures.append(f"absolute entry: {name}")
            if any(part == ".." for part in p.parts):
                failures.append(f"traversal entry: {name}")
    return failures


def validate(root: Path, archive: Path | None) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    notes: list[str] = []
    root = root.resolve()
    skill_path = root / "SKILL.md"
    manifest_path = root / "manifest.yaml"
    license_path = root / "LICENSE"
    openai_path = root / "agents" / "openai.yaml"
    for required in (skill_path, manifest_path, license_path, openai_path):
        if not required.is_file():
            failures.append(f"missing required file: {required.relative_to(root)}")
    if root.name != SKILL_NAME:
        failures.append(f"directory name is {root.name!r}, expected {SKILL_NAME!r}")

    fm = frontmatter(read_text(skill_path)) if skill_path.is_file() else {}
    if fm.get("name") != SKILL_NAME:
        failures.append("SKILL.md frontmatter name mismatch")
    if not fm.get("description"):
        failures.append("SKILL.md description missing")
    if fm.get("license") != "MIT":
        failures.append("SKILL.md license metadata is not MIT")
    if "compatibility" in fm:
        failures.append(
            "SKILL.md frontmatter must not contain a 'compatibility' key "
            "(rejected by the Codex validator; use a body section instead)"
        )
    skill_text = read_text(skill_path) if skill_path.is_file() else ""
    if "## Runtime requirements" not in skill_text:
        failures.append("SKILL.md body is missing the '## Runtime requirements' section")
    elif "Requires R for" not in skill_text:
        failures.append("SKILL.md Runtime requirements text is incomplete")

    mf = manifest_fields(read_text(manifest_path)) if manifest_path.is_file() else {}
    if mf.get("name") != SKILL_NAME:
        failures.append("manifest name mismatch")
    if mf.get("version") != VERSION:
        failures.append(f"manifest version is {mf.get('version')!r}, expected {VERSION!r}")
    if mf.get("license") != "MIT":
        failures.append("manifest license is not MIT")

    license_text = read_text(license_path) if license_path.is_file() else ""
    if "MIT License" not in license_text or "Copyright © 2026 Potato-AI" not in license_text:
        failures.append("LICENSE is not the expected MIT notice")
    readme_text = read_text(root / "README.md") if (root / "README.md").is_file() else ""
    if "MIT" not in readme_text:
        failures.append("README license metadata missing")

    ui_text = read_text(openai_path) if openai_path.is_file() else ""
    if 'display_name: "Potato Figure Audit"' not in ui_text:
        failures.append("agents/openai.yaml display_name missing or not human-readable")
    if "$potato-figure-audit" not in ui_text:
        failures.append("agents/openai.yaml default_prompt does not invoke $potato-figure-audit")

    for path in root.rglob("*"):
        if not path.is_file() or path.name == Path(__file__).name:
            continue
        if FORBIDDEN_FILE_RE.search(str(path.relative_to(root))):
            failures.append(f"forbidden release file: {path.relative_to(root)}")
        if path.suffix in TEXT_SUFFIXES:
            text = read_text(path)
            if ABSOLUTE_PATH_RE.search(text):
                failures.append(f"absolute path marker: {path.relative_to(root)}")
            if SECRET_RE.search(text):
                failures.append(f"possible secret marker: {path.relative_to(root)}")

    if archive:
        failures.extend(check_zip(archive))
    else:
        notes.append("ZIP_PATH_SCAN = NOT_EVALUATED (no archive supplied)")
    return failures, notes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, help="Skill root directory")
    parser.add_argument("--zip", dest="archive", type=Path, help="Optional ZIP to inspect")
    args = parser.parse_args()
    root = (args.root or Path(__file__).resolve().parents[1]).resolve()
    failures, notes = validate(root, args.archive.resolve() if args.archive else None)
    print(f"SKILL_ROOT = {root.name}")
    print(f"SKILL_NAME_DIRECTORY_MATCH = {'PASS' if root.name == SKILL_NAME else 'FAIL'}")
    print(f"PACKAGE_COMPLIANCE = {'PASS' if not failures else 'FAIL'}")
    for note in notes:
        print(note)
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("PACKAGE_COMPLIANCE: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
