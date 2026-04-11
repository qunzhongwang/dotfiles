#!/bin/bash
# =============================================================================
# Phase 2: Redirect caches to a persistent data disk
#
# Usage:
#   bash setup-disk.sh /path/to/disk                  # prompts for mode
#   bash setup-disk.sh /path/to/disk --symlink         # HPC: symlink ~/.cache -> disk
#   bash setup-disk.sh /path/to/disk --workspace       # Docker: everything under disk
#
# Modes:
#   symlink   — symlink ~/.cache to $DISK/.cache, conda dirs updated
#               Good for: HPC /scratch, where $HOME is persistent
#   workspace — all data lives directly under $DISK, $HOME is config-only
#               Good for: Docker /workspace, vast.ai, autodl
#
# This script is idempotent — safe to run multiple times.
# =============================================================================
set -euo pipefail

# Load .env if exists
[ -f "$HOME/.env" ] && source "$HOME/.env"

# --- Parse arguments ----------------------------------------------------------
DISK="${DISK:-}"
MODE=""

for arg in "$@"; do
  case "$arg" in
    --symlink)   MODE="symlink" ;;
    --workspace) MODE="workspace" ;;
    --help|-h)
      echo "Usage: bash setup-disk.sh /path/to/disk [--symlink|--workspace]"
      exit 0
      ;;
    *)
      # First non-flag argument is the disk path
      if [ -z "$DISK" ]; then
        DISK="$arg"
      fi
      ;;
  esac
done

if [ -z "$DISK" ]; then
  echo "ERROR: No disk path specified."
  echo "Usage: bash setup-disk.sh /path/to/disk [--symlink|--workspace]"
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

# --- Mode selection (interactive if not specified) ----------------------------
if [ -z "$MODE" ]; then
  echo ""
  echo "Select disk layout mode:"
  echo ""
  echo "  1) symlink   — symlink ~/.cache -> $DISK/.cache"
  echo "                  Good for: HPC with /scratch, persistent \$HOME"
  echo ""
  echo "  2) workspace — everything lives under $DISK directly"
  echo "                  Good for: Docker /workspace, vast.ai, autodl"
  echo ""
  printf "Enter 1 or 2: "
  read -r CHOICE
  case "$CHOICE" in
    1|symlink)   MODE="symlink" ;;
    2|workspace) MODE="workspace" ;;
    *)
      echo "ERROR: Invalid choice '$CHOICE'. Use 1/symlink or 2/workspace."
      exit 1
      ;;
  esac
fi

echo ""
echo "=== Setting up persistent disk at: $DISK (mode: $MODE) ==="

# --- Create directory structure -----------------------------------------------
echo "Creating cache directories..."
mkdir -p "$DISK/.cache/huggingface"
mkdir -p "$DISK/.cache/torch"
mkdir -p "$DISK/.cache/pip"
mkdir -p "$DISK/.cache/uv"
mkdir -p "$DISK/.cache/vllm"
mkdir -p "$DISK/.conda/envs"
mkdir -p "$DISK/.conda/pkgs"
mkdir -p "$DISK/wp"

# ==============================================================================
# MODE: symlink
# ==============================================================================
if [ "$MODE" = "symlink" ]; then
  echo "Setting up symlink mode..."

  # --- Symlink ~/.cache -------------------------------------------------------
  if [ -L "$HOME/.cache" ]; then
    CURRENT_TARGET="$(readlink "$HOME/.cache")"
    if [ "$CURRENT_TARGET" = "$DISK/.cache" ]; then
      echo "  ~/.cache already points to $DISK/.cache, skipping."
    else
      echo "  Repointing ~/.cache from $CURRENT_TARGET to $DISK/.cache"
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
    ln -sfn "$DISK/.cache" "$HOME/.cache"
    echo "  ~/.cache -> $DISK/.cache (fresh)"
  fi

  # --- Update .condarc --------------------------------------------------------
  echo "Updating .condarc with persistent disk paths..."
  CONDARC="$HOME/.condarc"
  if [ -f "$CONDARC" ] || [ -L "$CONDARC" ]; then
    REAL_CONDARC="$(readlink -f "$CONDARC")"
    if grep -q "$DISK/.conda/envs" "$REAL_CONDARC" 2>/dev/null; then
      echo "  .condarc already has $DISK paths, skipping."
    else
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
      echo "  Updated .condarc with $DISK paths."
    fi
  fi

# ==============================================================================
# MODE: workspace
# ==============================================================================
elif [ "$MODE" = "workspace" ]; then
  echo "Setting up workspace mode..."
  echo "  Caches:    $DISK/.cache/"
  echo "  Conda:     $DISK/.conda/"
  echo "  Workspace: $DISK/wp/"
  echo "  No symlinks created — zshrc will set env vars to point here directly."

  # --- Update .condarc to use workspace paths ---------------------------------
  CONDARC="$HOME/.condarc"
  if [ -f "$CONDARC" ] || [ -L "$CONDARC" ]; then
    REAL_CONDARC="$(readlink -f "$CONDARC")"
    if grep -q "$DISK/.conda/envs" "$REAL_CONDARC" 2>/dev/null; then
      echo "  .condarc already has $DISK paths, skipping."
    else
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
      echo "  Updated .condarc with $DISK paths."
    fi
  fi
fi

# --- Save DISK and DISK_MODE to .env -----------------------------------------
ENV_FILE="$HOME/.env"
if [ -f "$ENV_FILE" ]; then
  if grep -q "^DISK=" "$ENV_FILE"; then
    sed -i "s|^DISK=.*|DISK=${DISK}|" "$ENV_FILE"
  else
    echo "DISK=${DISK}" >> "$ENV_FILE"
  fi
  if grep -q "^DISK_MODE=" "$ENV_FILE"; then
    sed -i "s|^DISK_MODE=.*|DISK_MODE=${MODE}|" "$ENV_FILE"
  else
    echo "DISK_MODE=${MODE}" >> "$ENV_FILE"
  fi
else
  printf "DISK=%s\nDISK_MODE=%s\n" "$DISK" "$MODE" > "$ENV_FILE"
fi
chmod 600 "$ENV_FILE"

echo ""
echo "=== Persistent disk setup complete (mode: $MODE) ==="
echo ""
echo "Summary:"
echo "  DISK=$DISK"
echo "  DISK_MODE=$MODE"
if [ "$MODE" = "symlink" ]; then
  echo "  ~/.cache -> $DISK/.cache"
elif [ "$MODE" = "workspace" ]; then
  echo "  Caches at $DISK/.cache (direct, no symlinks)"
  echo "  Workspace at $DISK/wp"
fi
echo ""
echo "Restart your shell to pick up the changes: exec zsh"
