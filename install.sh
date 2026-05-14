#!/bin/bash
# =============================================================================
# Dotfiles: Main Install Script
# Bootstraps a complete ML development environment on any fresh Linux machine.
# Supports: Ubuntu/Debian, RHEL/CentOS/Rocky/Fedora, Docker containers
#
# Usage:
#   bash install.sh              # Full install
#   bash install.sh --no-system  # Skip system packages (no root needed)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_SYSTEM=false
AUTHORIZE_SELF=false

for arg in "$@"; do
  case "$arg" in
    --no-system|--cluster) SKIP_SYSTEM=true ;;
    --authorize-self) AUTHORIZE_SELF=true ;;
    --help|-h)
      echo "Usage: bash install.sh [--no-system | --cluster] [--authorize-self]"
      echo "  --no-system       Skip system package installation (no root needed)"
      echo "  --cluster         Same as --no-system; use on HPC clusters where sudo"
      echo "                    is unavailable. User-level tools (conda, nvm, fzf…)"
      echo "                    are still installed. System tools already present"
      echo "                    (e.g. tmux installed by sysadmin) are configured."
      echo "  --authorize-self  Append id_ed25519.pub to ~/.ssh/authorized_keys so"
      echo "                    any other machine using the same SSH_PRIVATE_KEY"
      echo "                    can SSH in here without a password."
      exit 0
      ;;
  esac
done
export AUTHORIZE_SELF

echo "=== Dotfiles Install ==="

# On macOS, ensure Homebrew is available and in PATH.
# `bash install.sh` starts with a minimal PATH that misses /opt/homebrew/bin,
# so probe known install locations first. If brew is not found at all, install it.
if [ "$(uname -s)" = "Darwin" ]; then
  for _brew_prefix in /opt/homebrew /usr/local "$HOME/.homebrew"; do
    if [ -x "$_brew_prefix/bin/brew" ]; then
      eval "$("$_brew_prefix/bin/brew" shellenv)"
      break
    fi
  done
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found — installing..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Re-probe after install (Apple Silicon lands in /opt/homebrew, Intel in /usr/local)
    for _brew_prefix in /opt/homebrew /usr/local; do
      if [ -x "$_brew_prefix/bin/brew" ]; then
        eval "$("$_brew_prefix/bin/brew" shellenv)"
        break
      fi
    done
  fi
fi

# Source .env if exists (secrets may come from .env OR bare env vars)
if [ -f "$HOME/.env" ]; then
  source "$HOME/.env"
  chmod 600 "$HOME/.env" 2>/dev/null || true
  echo "Loaded .env"
fi

# OS detection
source "$SCRIPT_DIR/scripts/detect-os.sh"

# Step 1: System packages
if [ "$SKIP_SYSTEM" = false ]; then
  echo ""
  echo "--- Installing system packages ---"
  bash "$SCRIPT_DIR/scripts/install-packages.sh"
else
  echo "Skipping system packages (--no-system / --cluster)"
fi

# Step 2: User-level tools
echo ""
echo "--- Installing user-level tools ---"
bash "$SCRIPT_DIR/scripts/install-tools.sh"

# Step 2.5: SSH keys (if SSH_PRIVATE_KEY is set)
echo ""
echo "--- Setting up SSH keys ---"
bash "$SCRIPT_DIR/scripts/setup-ssh.sh"

# Step 3: Link dotfiles
echo ""
echo "--- Linking dotfiles ---"
bash "$SCRIPT_DIR/scripts/link-dotfiles.sh"

# Install tmux plugins via TPM (non-interactive) — skip if tmux not installed
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ] && command -v tmux >/dev/null 2>&1; then
  echo "Installing tmux plugins..."
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
fi

# Step 4: Clone private repos
echo ""
echo "--- Cloning private repos ---"
bash "$SCRIPT_DIR/scripts/clone-repos.sh"

echo ""
echo "=== Done! ==="
echo "Start a new shell:  exec zsh"
echo ""
echo "Optional next steps:"
echo "  1. Set up secrets:  cp $SCRIPT_DIR/.env.example ~/.env && vim ~/.env"
echo "  2. Redirect cache:  bash $SCRIPT_DIR/setup-disk.sh /path/to/datadisk"
