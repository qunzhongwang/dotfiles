#!/bin/bash
# =============================================================================
# Symlink VS Code launch.json template into $WORKSPACE_DIR/.vscode/
# Same pattern as link-dotfiles.sh: git pull in dotfiles updates workspace live.
# Existing non-symlink files at the target are backed up to .bak.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env if exists (may set WORKSPACE_DIR, DISK, DISK_MODE)
[ -f "$HOME/.env" ] && source "$HOME/.env"

# Resolve workspace dir with same logic as zshrc
: "${DISK:=$HOME}"
: "${DISK_MODE:=symlink}"
if [ -z "${WORKSPACE_DIR:-}" ]; then
  if [ "$DISK_MODE" = "workspace" ] && [ "$DISK" != "$HOME" ]; then
    WORKSPACE_DIR="$DISK/wp"
  else
    WORKSPACE_DIR="$HOME/wp"
  fi
fi

TEMPLATE="$DOTFILES_DIR/templates/vscode/launch.json"
TARGET_DIR="$WORKSPACE_DIR/.vscode"
TARGET="$TARGET_DIR/launch.json"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template not found at $TEMPLATE"
  exit 1
fi

mkdir -p "$TARGET_DIR"

# Back up existing real file (not a symlink) before replacing
if [ -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
  echo "  Backing up $TARGET -> ${TARGET}.bak"
  mv "$TARGET" "${TARGET}.bak"
fi

ln -sfn "$TEMPLATE" "$TARGET"
echo "Linked VS Code launch.json: $TARGET -> $TEMPLATE"
