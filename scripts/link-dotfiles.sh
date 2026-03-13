#!/bin/bash
# =============================================================================
# Symlink config files into $HOME
# Backs up existing non-symlink files as .bak
# =============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"

echo "Linking dotfiles from $CONFIG_DIR into $HOME..."

for f in "$CONFIG_DIR"/*; do
  name=".$(basename "$f")"
  target="$HOME/$name"

  # Back up existing real files (not symlinks)
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "  Backing up $target -> ${target}.bak"
    mv "$target" "${target}.bak"
  fi

  ln -sfn "$f" "$target"
  echo "  Linked $target -> $f"
done

echo "Dotfiles linked."
