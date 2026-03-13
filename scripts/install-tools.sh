#!/bin/bash
# =============================================================================
# Install user-level tools: oh-my-zsh, fzf, nvm, conda, claude, cloudflared
# Each tool checks if already installed before proceeding.
# =============================================================================
set -euo pipefail

echo "Installing user-level tools..."

# --- Oh My Zsh ----------------------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh already installed, skipping."
fi

# Oh My Zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  echo "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
  echo "Installing zsh-completions..."
  git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
fi

# --- FZF ----------------------------------------------------------------------
if [ ! -d "$HOME/.fzf" ]; then
  echo "Installing fzf..."
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-update-rc
else
  echo "fzf already installed, skipping."
fi

# --- NVM + Node ---------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  echo "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  # Load nvm for this session
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  echo "Installing Node.js LTS..."
  nvm install --lts
else
  echo "nvm already installed, skipping."
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
fi

# --- Miniconda3 ---------------------------------------------------------------
if [ ! -d "$HOME/miniconda3" ]; then
  echo "Installing Miniconda3..."
  ARCH=$(uname -m)
  MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${ARCH}.sh"
  curl -fsSL "$MINICONDA_URL" -o /tmp/miniconda.sh
  bash /tmp/miniconda.sh -b -p "$HOME/miniconda3"
  rm -f /tmp/miniconda.sh
  # Initialize for current session
  eval "$("$HOME/miniconda3/bin/conda" 'shell.bash' 'hook' 2>/dev/null)" || true
  conda config --set auto_activate_base false
else
  echo "Miniconda3 already installed, skipping."
fi

# --- Claude Code CLI ----------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  echo "Installing Claude Code CLI..."
  # Ensure npm is available
  if command -v npm >/dev/null 2>&1; then
    npm install -g @anthropic-ai/claude-code
  else
    echo "WARNING: npm not found. Skipping Claude Code CLI installation."
    echo "  Install it manually after nvm/node is set up: npm install -g @anthropic-ai/claude-code"
  fi
else
  echo "Claude Code CLI already installed, skipping."
fi

# --- Cloudflared --------------------------------------------------------------
mkdir -p "$HOME/bin"
if [ ! -f "$HOME/bin/cloudflared" ]; then
  echo "Installing cloudflared..."
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) CF_ARCH="amd64" ;;
    aarch64) CF_ARCH="arm64" ;;
    *) echo "WARNING: Unsupported architecture $ARCH for cloudflared. Skipping."; CF_ARCH="" ;;
  esac
  if [ -n "$CF_ARCH" ]; then
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o "$HOME/bin/cloudflared"
    chmod +x "$HOME/bin/cloudflared"
  fi
else
  echo "cloudflared already installed, skipping."
fi

echo "All user-level tools installed."
