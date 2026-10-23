#!/usr/bin/env bash
# Idempotent environment setup: Godot headless, export templates, gdUnit4, gdtoolkit, Pillow.
set -euo pipefail

# Single source of truth is the Makefile (it exports these); defaults for direct runs.
GODOT_VERSION="${GODOT_VERSION:-4.7.2-stable}"
# gdUnit4: no v7 tags exist yet (latest v6.2.2); master is v7.0.0 and needs Godot 4.7+. Pin a v7.x tag once released.
GDUNIT_REF="${GDUNIT_REF:-master}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/.tools"
BASE_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}"
TEMPLATE_DIR_NAME="${GODOT_VERSION/-/.}" # 4.7.2-stable -> 4.7.2.stable

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
  Darwin)
    GODOT_ZIP="Godot_v${GODOT_VERSION}_macos.universal.zip"
    TEMPLATES_ROOT="$HOME/Library/Application Support/Godot/export_templates"
    ;;
  Linux)
    case "$ARCH" in
      x86_64) GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip" ;;
      aarch64 | arm64) GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.arm64.zip" ;;
      *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
    esac
    TEMPLATES_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"
    ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac
TEMPLATES_ZIP="Godot_v${GODOT_VERSION}_export_templates.tpz"

mkdir -p "$TOOLS"

fetch() { # fetch <url> <dest>
  curl -fsSL --retry 3 --retry-delay 2 -o "$2.part" "$1"
  mv "$2.part" "$2"
}

# --- Godot binary ---
want_marker="$TOOLS/.godot_version"
if [ -x "$TOOLS/godot" ] && [ "$(cat "$want_marker" 2>/dev/null)" = "$GODOT_VERSION" ]; then
  echo "[setup] Godot $GODOT_VERSION already present"
else
  echo "[setup] Downloading $GODOT_ZIP"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  fetch "$BASE_URL/$GODOT_ZIP" "$tmp/godot.zip"
  rm -rf "$TOOLS/godot" "$TOOLS/Godot.app"
  if [ "$OS" = "Darwin" ]; then
    unzip -q "$tmp/godot.zip" -d "$TOOLS"
    ln -sf "$TOOLS/Godot.app/Contents/MacOS/Godot" "$TOOLS/godot"
  else
    unzip -q "$tmp/godot.zip" -d "$tmp/x"
    mv "$tmp"/x/Godot_v* "$TOOLS/godot"
    chmod +x "$TOOLS/godot"
  fi
  echo "$GODOT_VERSION" > "$want_marker"
fi

# --- Export templates (only when missing) ---
if [ -d "$TEMPLATES_ROOT/$TEMPLATE_DIR_NAME" ] && [ -n "$(ls -A "$TEMPLATES_ROOT/$TEMPLATE_DIR_NAME" 2>/dev/null)" ]; then
  echo "[setup] Export templates already present"
else
  echo "[setup] Downloading export templates"
  tmp2="$(mktemp -d)"
  fetch "$BASE_URL/$TEMPLATES_ZIP" "$tmp2/templates.tpz"
  unzip -q "$tmp2/templates.tpz" -d "$tmp2/x"
  mkdir -p "$TEMPLATES_ROOT"
  rm -rf "${TEMPLATES_ROOT:?}/$TEMPLATE_DIR_NAME"
  mv "$tmp2/x/templates" "$TEMPLATES_ROOT/$TEMPLATE_DIR_NAME"
  rm -rf "$tmp2"
fi

# --- gdUnit4 (cloned, never vendored; repo keeps addon under addons/gdUnit4) ---
ADDON="$ROOT/game/addons/gdUnit4"
if [ -f "$ADDON/plugin.cfg" ]; then
  echo "[setup] gdUnit4 already present"
else
  echo "[setup] Cloning gdUnit4 ($GDUNIT_REF)"
  tmp3="$(mktemp -d)"
  git clone --depth 1 --branch "$GDUNIT_REF" https://github.com/MikeSchulze/gdUnit4 "$tmp3/gdunit" >/dev/null 2>&1
  mkdir -p "$ROOT/game/addons"
  rm -rf "$ADDON"
  mv "$tmp3/gdunit/addons/gdUnit4" "$ADDON"
  rm -rf "$tmp3"
fi

# --- gdtoolkit (gdlint / gdformat) ---
if command -v gdlint >/dev/null 2>&1 && command -v gdformat >/dev/null 2>&1; then
  echo "[setup] gdtoolkit already present"
else
  echo "[setup] Installing gdtoolkit"
  pip install --break-system-packages gdtoolkit || pip3 install --break-system-packages gdtoolkit
fi

# --- Pillow (tools/gen_assets.py: PNG sprites/icons) ---
if python3 -c "import PIL" 2>/dev/null; then
  echo "[setup] Pillow already present"
else
  echo "[setup] Installing Pillow"
  pip install --break-system-packages pillow || pip3 install --break-system-packages pillow
fi

# Import resources once so class_name cache exists for headless runs.
"$TOOLS/godot" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true

"$TOOLS/godot" --version
