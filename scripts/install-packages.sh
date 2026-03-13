#!/bin/bash
# =============================================================================
# Install system packages — auto-detects apt vs dnf
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/detect-os.sh"

if [ -z "$PKG_MGR" ]; then
  echo "ERROR: No package manager detected. Skipping system package installation."
  exit 0
fi

# Check if we can install packages (need root or sudo)
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "WARNING: Not root and sudo not available. Skipping system package installation."
    exit 0
  fi
else
  SUDO=""
fi

echo "Installing system packages with $PKG_MGR..."

case "$PKG_MGR" in
  apt-get)
    $SUDO apt-get update
    $SUDO apt-get install -y \
      zsh \
      git \
      git-lfs \
      tmux \
      ripgrep \
      fd-find \
      neovim \
      curl \
      wget \
      xclip \
      unzip \
      jq \
      ca-certificates \
      build-essential
    ;;
  dnf)
    # Enable EPEL for ripgrep, fd-find, neovim on RHEL-family
    if ! rpm -q epel-release >/dev/null 2>&1; then
      $SUDO dnf install -y epel-release || echo "WARNING: Could not install EPEL. Some packages may be unavailable."
    fi
    $SUDO dnf install -y \
      zsh \
      git \
      git-lfs \
      tmux \
      ripgrep \
      fd-find \
      neovim \
      curl \
      wget \
      xclip \
      unzip \
      jq \
      ca-certificates \
      gcc \
      gcc-c++ \
      make
    ;;
esac

# Initialize git-lfs
git lfs install 2>/dev/null || true

echo "System packages installed."
