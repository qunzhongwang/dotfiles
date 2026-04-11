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

for arg in "$@"; do
  case "$arg" in
    --no-system) SKIP_SYSTEM=true ;;
    --help|-h)
      echo "Usage: bash install.sh [--no-system]"
      echo "  --no-system  Skip system package installation (no root needed)"
      exit 0
      ;;
  esac
done

echo "=== Dotfiles Install ==="

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
  echo "Skipping system packages (--no-system)"
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

# Install tmux plugins via TPM (non-interactive)
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
  echo "Installing tmux plugins..."
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
fi

# Step 4: Clone private repos
echo ""
echo "--- Cloning private repos ---"
bash "$SCRIPT_DIR/scripts/clone-repos.sh"

# Step 5: Install VS Code launch.json template
echo ""
echo "--- Setting up VS Code debug config ---"
bash "$SCRIPT_DIR/scripts/setup-vscode.sh"

echo ""
echo "=== Done! ==="
echo "Start a new shell:  exec zsh"
echo ""
echo "Optional next steps:"
echo "  1. Set up secrets:  cp $SCRIPT_DIR/.env.example ~/.env && vim ~/.env"
echo "  2. Redirect cache:  bash $SCRIPT_DIR/setup-disk.sh /path/to/datadisk"
