#!/bin/bash
# =============================================================================
# Copy VS Code launch.json template into $WORKSPACE_DIR/.vscode/
# Idempotent: only copies if the target file does not already exist.
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

if [ -f "$TARGET" ]; then
  echo "VS Code launch.json already exists at $TARGET, skipping."
else
  cp "$TEMPLATE" "$TARGET"
  echo "Installed VS Code launch.json -> $TARGET"
fi
