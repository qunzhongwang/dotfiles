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

# brew doesn't need sudo; Linux needs root or sudo
if [ "$PKG_MGR" = "brew" ]; then
  SUDO=""
elif [ "$(id -u)" -ne 0 ]; then
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
  brew)
    if ! command -v brew >/dev/null 2>&1; then
      echo "WARNING: Homebrew not found. Install from https://brew.sh then re-run."
      exit 0
    fi
    brew install \
      git \
      git-lfs \
      tmux \
      ripgrep \
      fd \
      neovim \
      wget \
      jq
    ;;
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
