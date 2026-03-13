#!/bin/bash
# =============================================================================
# Clone private repos if GITHUB_TOKEN is available
# Works with tokens from .env file OR bare env vars (vast.ai/autodl)
# =============================================================================
set -euo pipefail

: "${WORKSPACE_DIR:=$HOME/wp}"
: "${GITHUB_USER:=qunzhongwang}"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "WARNING: GITHUB_TOKEN not set. Skipping private repo cloning."
  echo "  Set GITHUB_TOKEN in .env or as an environment variable to enable."
  exit 0
fi

mkdir -p "$WORKSPACE_DIR"

# Clone routines repo
ROUTINES_DIR="$WORKSPACE_DIR/routines"
if [ ! -d "$ROUTINES_DIR" ]; then
  echo "Cloning routines repo..."
  git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/routines.git" "$ROUTINES_DIR"
  echo "Routines cloned to $ROUTINES_DIR"
else
  echo "Routines already exist at $ROUTINES_DIR, skipping."
fi

# Add more private repos here as needed:
# REPO_DIR="$WORKSPACE_DIR/repo-name"
# if [ ! -d "$REPO_DIR" ]; then
#   git clone "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/repo-name.git" "$REPO_DIR"
# fi

echo "Private repo cloning done."
