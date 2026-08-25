#!/usr/bin/env python3
"""Fail closed when publication-unsafe artifacts enter the project tree."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKIP_PARTS = {".git", "__pycache__", ".venv"}
BANNED_SUFFIXES = {
    ".deb", ".iso", ".img", ".zst", ".tar", ".tgz", ".gz", ".zip",
    ".key", ".pem", ".p12", ".pfx", ".sqlite", ".db",
}
BANNED_NAMES = {"mqtt.env", "profile.env"}
BANNED_PATTERNS = {
    "private household hostname": re.compile(r"mitchell-collins", re.I),
    "private LAN address": re.compile(r"192\.168\.88\."),
    "historical shared password": re.compile(r"rsv-[A-Za-z0-9]+"),
    "historical fixed device ID": re.compile(r"rpi_75CE76", re.I),
    "historical device name": re.compile(r"reserva-1", re.I),
    "historical fixed home": re.compile(r"/home/dashboard", re.I),
    "TouchKio credential scraping": re.compile(r"Arguments\.json|decrypt_touchkio", re.I),
    "private key material": re.compile(r"BEGIN (?:OPENSSH|RSA|EC|DSA) PRIVATE KEY"),
}


def included_files():
    for path in ROOT.rglob("*"):
        if not path.is_file() or any(part in SKIP_PARTS for part in path.parts):
            continue
        yield path


def main() -> int:
    problems: list[str] = []
    for path in included_files():
        relative = path.relative_to(ROOT)
        if path.name in BANNED_NAMES or path.name.endswith(".local.env"):
            problems.append(f"local configuration file must not be published: {relative}")
            continue
        if any(path.name.lower().endswith(suffix) for suffix in BANNED_SUFFIXES):
            problems.append(f"forbidden artifact type: {relative}")
            continue
        if path.stat().st_size > 1_000_000:
            problems.append(f"file exceeds 1 MB publication limit: {relative}")
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            problems.append(f"non-text file is not permitted: {relative}")
            continue
        if relative == Path("scripts/validate-repository.py"):
            continue
        for label, pattern in BANNED_PATTERNS.items():
            if pattern.search(content):
                problems.append(f"{label}: {relative}")

    if problems:
        for problem in problems:
            print(f"ERROR: {problem}", file=sys.stderr)
        return 1
    print("Repository publication guard passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
