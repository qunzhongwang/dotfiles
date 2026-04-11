# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Portable ML development environment (dotfiles + Docker) for GPU cloud instances (vast.ai, autodl) and HPC clusters. Targets Ubuntu 22.04 (primary) and RHEL/CentOS/Rocky (secondary).

## Key Commands

```bash
# Full install on bare metal
bash install.sh

# Install without system packages (no root needed)
bash install.sh --no-system

# Redirect caches to persistent data disk (prompts for mode)
bash setup-disk.sh /path/to/datadisk
bash setup-disk.sh /path/to/disk --symlink    # HPC: symlink ~/.cache
bash setup-disk.sh /path/to/disk --workspace   # Docker: direct paths under disk

# Re-link dotfiles after changes
bash scripts/link-dotfiles.sh

# Docker builds
docker build -f docker/Dockerfile.ubuntu -t ghcr.io/qunzhongwang/ml-env:latest .   # GPU (CUDA 12.8)
docker build -f docker/Dockerfile.cpu -t ml-env:latest .                             # CPU-only
docker build -f docker/Dockerfile.rhel -t ghcr.io/qunzhongwang/ml-env:rhel .        # RHEL variant
```

## Architecture

**Two-phase bootstrap model:**
1. `install.sh` runs modular scripts in order: `detect-os.sh` → `install-packages.sh` → `install-tools.sh` → `setup-ssh.sh` → `link-dotfiles.sh` → TPM plugin install → `clone-repos.sh`
2. `setup-disk.sh` (run manually after mounting a data disk) supports two modes:
   - `--symlink`: symlinks `~/.cache` → `$DISK/.cache` (HPC with `/scratch`)
   - `--workspace`: everything lives under `$DISK` directly, `$HOME` is config-only (Docker `/workspace`, vast.ai, autodl)

**SSH keys:** Set `SSH_PRIVATE_KEY` (base64-encoded Ed25519) in `.env`. `scripts/setup-ssh.sh` decodes it, derives the pubkey, sets up `~/.ssh/config` for GitHub, and creates `allowed_signers` for git commit signing. Called from both `install.sh` and `docker/entrypoint.sh`.

**Secrets flow:** Never baked into Docker images. Injected at runtime via `--env-file .env`, bare env vars (cloud UI), or mounted files. `docker/entrypoint.sh` reads these and configures SSH keys, git credentials, HF token, and wandb `.netrc`.

**tmux:** Uses TPM (Tmux Plugin Manager) with plugins: tmux-sensible, tmux-yank (OSC 52 copy-paste for headless servers), tmux-resurrect. TPM installed by `install-tools.sh`, plugins installed non-interactively by `install.sh`.

**Config files in `config/`** are symlinked to `~/.<name>` by `scripts/link-dotfiles.sh`. Edit the files in `config/`, not the symlinked copies.

**OS detection** (`scripts/detect-os.sh`): Sources `/etc/os-release` and exports `DISTRO`, `PKG_MGR`, `PKG_INSTALL` for downstream scripts to use.

## Conventions

- All scripts use `set -euo pipefail` and are idempotent (safe to re-run)
- Scripts skip already-installed tools rather than reinstalling
- `.env` file at `~/.env` holds secrets; `.env.example` is the committed template
- `DISK` env var controls the persistent storage root (defaults to `$HOME`)
- `DISK_MODE` env var: `symlink` (default) or `workspace` — controls disk layout strategy
- `WORKSPACE_DIR` env var controls where repos are cloned (defaults to `~/wp`, or `$DISK/wp` in workspace mode)
- `SSH_PRIVATE_KEY` env var: base64-encoded Ed25519 key for SSH auth + git signing
