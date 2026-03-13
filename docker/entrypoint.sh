#!/bin/bash
# =============================================================================
# Docker entrypoint: load secrets and configure tools at runtime
# Supports both .env file (--env-file) and bare env vars (vast.ai/autodl UI)
# =============================================================================

# Load .env if mounted or present (bare env vars from cloud UI take precedence)
[ -f "$HOME/.env" ] && source "$HOME/.env"

# Auto-generate .netrc for wandb
if [ -n "${WANDB_API_KEY:-}" ]; then
  printf "machine api.wandb.ai\n  login user\n  password %s\n" "$WANDB_API_KEY" > "$HOME/.netrc"
  chmod 600 "$HOME/.netrc"
fi

# Auto-configure git credentials for private repo access
if [ -n "${GITHUB_TOKEN:-}" ]; then
  git config --global credential.helper \
    '!f() { echo "username=x-access-token"; echo "password='"${GITHUB_TOKEN}"'"; }; f'
fi

# Auto-configure HuggingFace CLI
if [ -n "${HF_TOKEN:-}" ]; then
  mkdir -p "${HF_HOME:-$HOME/.cache/huggingface}"
  echo -n "$HF_TOKEN" > "${HF_HOME:-$HOME/.cache/huggingface}/token"
fi

# Warnings for missing tokens
[ -z "${HF_TOKEN:-}" ] && echo "NOTE: HF_TOKEN not set — gated model downloads will fail"
[ -z "${GITHUB_TOKEN:-}" ] && echo "NOTE: GITHUB_TOKEN not set — private repo cloning disabled"

exec "$@"
