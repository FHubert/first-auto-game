#!/usr/bin/env python3
"""Validate export_presets.cfg: required placeholders present, no real secrets.

Usage: validate_presets.py [path/to/export_presets.cfg]
Exit code 0 = OK, 1 = problems found.
"""
import re
import sys
from pathlib import Path

DEFAULT_PATH = Path(__file__).resolve().parent.parent / "game" / "export_presets.cfg"

# Keys that must hold a __PLACEHOLDER__ value in the committed file.
REQUIRED_PLACEHOLDERS = {
    "keystore/release": "__ANDROID_KEYSTORE_PATH__",
    "keystore/release_user": "__ANDROID_KEY_ALIAS__",
    "keystore/release_password": "__ANDROID_KEY_PASSWORD__",
    "application/app_store_team_id": "__APPLE_TEAM_ID__",
}
# Secret-ish keys: value must be empty or a placeholder.
SECRET_KEY_RE = re.compile(r"(password|keystore|_user$|team_id|provisioning_profile_uuid|code_sign_identity|salt|public_key)", re.I)
PLACEHOLDER_RE = re.compile(r"^__[A-Z0-9_]+__$")
SECRET_PATTERNS = [
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"ca-app-pub-\d{10,}"),
    re.compile(r"\.(keystore|jks|p8|p12)\b", re.I),
]
EXPECTED_ID = "pl.allinit.firstautogame"


def parse(text: str) -> dict:
    """Return {key: value} for all [preset.N.options] sections (key prefixed with N:)."""
    out, section = {}, None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            section = m.group(1)
            continue
        if "=" in line and section:
            k, v = line.split("=", 1)
            out[(section, k.strip())] = v.strip().strip('"')
    return out


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PATH
    if not path.is_file():
        print(f"ERROR: {path} not found")
        return 1
    text = path.read_text(encoding="utf-8")
    cfg = parse(text)
    errors = []

    for key, expected in REQUIRED_PLACEHOLDERS.items():
        values = [v for (sec, k), v in cfg.items() if k == key]
        if not values:
            errors.append(f"missing key {key}")
        elif any(v != expected for v in values):
            errors.append(f"{key} must be {expected}, got {values}")

    for (sec, k), v in cfg.items():
        if SECRET_KEY_RE.search(k) and v and not PLACEHOLDER_RE.match(v):
            errors.append(f"[{sec}] {k} holds a non-placeholder value")

    for pat in SECRET_PATTERNS:
        if pat.search(text):
            errors.append(f"secret-like pattern found: {pat.pattern}")

    for key in ("package/unique_name", "application/bundle_identifier"):
        values = [v for (sec, k), v in cfg.items() if k == key]
        if not values:
            errors.append(f"missing key {key}")
        elif any(v != EXPECTED_ID for v in values):
            errors.append(f"{key} should be {EXPECTED_ID}, got {values}")

    names = [v for (sec, k), v in cfg.items() if k == "name" and re.fullmatch(r"preset\.\d+", sec)]
    for required in ("Android", "iOS"):
        if required not in names:
            errors.append(f"missing preset {required}")

    if errors:
        print("export_presets.cfg INVALID:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("export_presets.cfg OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
