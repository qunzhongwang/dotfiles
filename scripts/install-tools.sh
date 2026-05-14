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
  UNAME_S=$(uname -s)
  UNAME_M=$(uname -m)
  case "$UNAME_S" in
    Linux)  CONDA_OS="Linux" ;;
    Darwin) CONDA_OS="MacOSX" ;;
    *) echo "WARNING: Unsupported OS $UNAME_S for Miniconda3. Skipping."; CONDA_OS="" ;;
  esac
  case "$UNAME_M" in
    x86_64|aarch64|arm64) CONDA_ARCH="$UNAME_M" ;;
    *) echo "WARNING: Unsupported architecture $UNAME_M for Miniconda3. Skipping."; CONDA_ARCH="" ;;
  esac
  if [ -n "$CONDA_OS" ] && [ -n "$CONDA_ARCH" ]; then
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-${CONDA_OS}-${CONDA_ARCH}.sh"
    curl -fsSL "$MINICONDA_URL" -o /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3"
    rm -f /tmp/miniconda.sh
    eval "$("$HOME/miniconda3/bin/conda" 'shell.bash' 'hook' 2>/dev/null)" || true
    conda config --set auto_activate_base false
  fi
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
  CF_UNAME_S=$(uname -s)
  CF_UNAME_M=$(uname -m)
  case "$CF_UNAME_S" in
    Linux)  CF_OS="linux" ;;
    Darwin) CF_OS="darwin" ;;
    *) echo "WARNING: Unsupported OS $CF_UNAME_S for cloudflared. Skipping."; CF_OS="" ;;
  esac
  case "$CF_UNAME_M" in
    x86_64)        CF_ARCH="amd64" ;;
    aarch64|arm64) CF_ARCH="arm64" ;;
    *) echo "WARNING: Unsupported architecture $CF_UNAME_M for cloudflared. Skipping."; CF_ARCH="" ;;
  esac
  if [ -n "$CF_OS" ] && [ -n "$CF_ARCH" ]; then
    CF_BASE="https://github.com/cloudflare/cloudflared/releases/latest/download"
    if [ "$CF_OS" = "darwin" ]; then
      # macOS releases are tarballs
      curl -fsSL "${CF_BASE}/cloudflared-darwin-${CF_ARCH}.tgz" -o /tmp/cloudflared.tgz
      tar -xzf /tmp/cloudflared.tgz -C /tmp/
      mv /tmp/cloudflared "$HOME/bin/cloudflared"
      rm -f /tmp/cloudflared.tgz
    else
      curl -fsSL "${CF_BASE}/cloudflared-linux-${CF_ARCH}" -o "$HOME/bin/cloudflared"
    fi
    chmod +x "$HOME/bin/cloudflared"
  fi
else
  echo "cloudflared already installed, skipping."
fi

# --- TPM (Tmux Plugin Manager) ------------------------------------------------
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
  echo "Installing TPM (Tmux Plugin Manager)..."
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
  echo "TPM already installed, skipping."
fi

echo "All user-level tools installed."
