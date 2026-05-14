#!/bin/bash
set -euo pipefail

# Load .env if it exists
if [ -f "$HOME/.env" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.env"
fi

# Exit silently if SSH_PRIVATE_KEY is not set
if [ -z "${SSH_PRIVATE_KEY:-}" ]; then
  echo "SSH_PRIVATE_KEY not set, skipping SSH key setup."
  exit 0
fi

# Create ~/.ssh with correct permissions
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# Decode base64 private key
echo "$SSH_PRIVATE_KEY" | base64 -d > "$HOME/.ssh/id_ed25519"
chmod 600 "$HOME/.ssh/id_ed25519"

# Derive public key from private key
ssh-keygen -y -f "$HOME/.ssh/id_ed25519" > "$HOME/.ssh/id_ed25519.pub"
chmod 644 "$HOME/.ssh/id_ed25519.pub"

# Get email for allowed_signers
EMAIL=$(git config --global user.email 2>/dev/null || echo "user@example.com")
if [ -z "$EMAIL" ]; then
  EMAIL="user@example.com"
fi

# Create allowed_signers file
echo "$EMAIL $(cat "$HOME/.ssh/id_ed25519.pub")" > "$HOME/.ssh/allowed_signers"
chmod 644 "$HOME/.ssh/allowed_signers"

# Append GitHub SSH config only if not already present
if ! grep -q "Host github.com" "$HOME/.ssh/config" 2>/dev/null; then
  cat >> "$HOME/.ssh/config" <<'EOF'

Host github.com
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
EOF
  chmod 600 "$HOME/.ssh/config"
fi

# Optionally authorize this machine's own pubkey so any peer sharing the same
# SSH_PRIVATE_KEY can SSH in without a password (fleet self-trust pattern).
if [ "${AUTHORIZE_SELF:-false}" = "true" ]; then
  AUTH_KEYS="$HOME/.ssh/authorized_keys"
  touch "$AUTH_KEYS"
  chmod 600 "$AUTH_KEYS"
  PUB=$(cat "$HOME/.ssh/id_ed25519.pub")
  if ! grep -qxF "$PUB" "$AUTH_KEYS"; then
    echo "$PUB" >> "$AUTH_KEYS"
    echo "Authorized id_ed25519.pub in ~/.ssh/authorized_keys (passwordless SSH for peers with the same key)."
  else
    echo "id_ed25519.pub already present in authorized_keys, skipping."
  fi
fi

echo "SSH key configured (ed25519, GitHub-only)."
