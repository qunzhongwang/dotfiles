#!/bin/bash
# =============================================================================
# Phase 2: Redirect caches to a persistent data disk
#
# Usage:
#   bash setup-disk.sh /path/to/datadisk
#   # or set DISK in .env and run:
#   bash setup-disk.sh
#
# This script is idempotent — safe to run multiple times.
# =============================================================================
set -euo pipefail

# Load .env if exists
[ -f "$HOME/.env" ] && source "$HOME/.env"

# Get DISK path from argument or .env
DISK="${1:-${DISK:-}}"

if [ -z "$DISK" ]; then
  echo "ERROR: No disk path specified."
  echo "Usage: bash setup-disk.sh /path/to/datadisk"
  echo "   or: set DISK=/path/to/datadisk in ~/.env"
  exit 1
fi

if [ ! -d "$DISK" ]; then
  echo "ERROR: $DISK does not exist or is not a directory."
  exit 1
fi

if [ ! -w "$DISK" ]; then
  echo "ERROR: $DISK is not writable."
  exit 1
fi

echo "=== Setting up persistent disk at: $DISK ==="

# --- Create directory structure -----------------------------------------------
echo "Creating cache directories..."
mkdir -p "$DISK/.cache/huggingface"
mkdir -p "$DISK/.cache/torch"
mkdir -p "$DISK/.cache/pip"
mkdir -p "$DISK/.cache/uv"
mkdir -p "$DISK/.cache/vllm"
mkdir -p "$DISK/.conda/envs"
mkdir -p "$DISK/.conda/pkgs"

# --- Migrate and symlink ~/.cache ---------------------------------------------
echo "Setting up ~/.cache symlink..."
if [ -L "$HOME/.cache" ]; then
  CURRENT_TARGET="$(readlink "$HOME/.cache")"
  if [ "$CURRENT_TARGET" = "$DISK/.cache" ]; then
    echo "  ~/.cache already points to $DISK/.cache, skipping."
  else
    echo "  Repointing ~/.cache from $CURRENT_TARGET to $DISK/.cache"
    # Try to migrate from old target if it exists
    if [ -d "$CURRENT_TARGET" ]; then
      echo "  Migrating contents from $CURRENT_TARGET..."
      rsync -a --ignore-existing "$CURRENT_TARGET/" "$DISK/.cache/" || true
    fi
    ln -sfn "$DISK/.cache" "$HOME/.cache"
  fi
elif [ -d "$HOME/.cache" ]; then
  echo "  Migrating existing ~/.cache to $DISK/.cache..."
  rsync -a --ignore-existing "$HOME/.cache/" "$DISK/.cache/"
  RSYNC_EXIT=$?
  if [ $RSYNC_EXIT -ne 0 ]; then
    echo "  WARNING: rsync exited with code $RSYNC_EXIT. Keeping original ~/.cache as backup."
    mv "$HOME/.cache" "$HOME/.cache.bak"
  else
    rm -rf "$HOME/.cache"
  fi
  ln -sfn "$DISK/.cache" "$HOME/.cache"
  echo "  ~/.cache -> $DISK/.cache"
else
  # No existing ~/.cache
  ln -sfn "$DISK/.cache" "$HOME/.cache"
  echo "  ~/.cache -> $DISK/.cache (fresh)"
fi

# --- Update .condarc ----------------------------------------------------------
echo "Updating .condarc with persistent disk paths..."
CONDARC="$HOME/.condarc"
if [ -f "$CONDARC" ] || [ -L "$CONDARC" ]; then
  # Read the actual file (following symlinks)
  REAL_CONDARC="$(readlink -f "$CONDARC")"

  # Check if $DISK paths are already in condarc
  if grep -q "$DISK/.conda/envs" "$REAL_CONDARC" 2>/dev/null; then
    echo "  .condarc already has $DISK paths, skipping."
  else
    # Prepend $DISK paths to envs_dirs and pkgs_dirs
    # Write a new condarc with disk paths first, then existing paths as fallback
    cat > /tmp/condarc_new <<CONDARC_EOF
envs_dirs:
  - ${DISK}/.conda/envs
  - ~/miniconda3/envs
  - ~/.conda/envs
pkgs_dirs:
  - ${DISK}/.conda/pkgs
  - ~/miniconda3/pkgs
  - ~/.conda/pkgs
auto_activate_base: false
changeps1: true
CONDARC_EOF
    cp /tmp/condarc_new "$REAL_CONDARC"
    rm -f /tmp/condarc_new
    echo "  Updated .condarc with $DISK paths (originals kept as fallback)."
  fi
fi

# --- Update DISK in .env if not already set -----------------------------------
ENV_FILE="$HOME/.env"
if [ -f "$ENV_FILE" ]; then
  if grep -q "^DISK=" "$ENV_FILE"; then
    # Update existing DISK line
    sed -i "s|^DISK=.*|DISK=${DISK}|" "$ENV_FILE"
  else
    echo "DISK=${DISK}" >> "$ENV_FILE"
  fi
else
  echo "DISK=${DISK}" > "$ENV_FILE"
fi
chmod 600 "$ENV_FILE"

echo ""
echo "=== Persistent disk setup complete ==="
echo ""
echo "Summary:"
echo "  DISK=$DISK"
echo "  ~/.cache -> $DISK/.cache"
echo "  .condarc envs_dirs: $DISK/.conda/envs (primary) + local fallbacks"
echo ""
echo "Restart your shell to pick up the changes: exec zsh"
