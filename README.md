# dotfiles

Portable ML development environment for GPU cloud instances and HPC clusters.

One `install.sh` to bootstrap any fresh Linux machine. One `setup-disk.sh` to redirect caches to a persistent data disk. Dockerfiles for `nvidia/cuda` base images. Secrets via `.env` file or bare env vars.

## What's Inside

| Component | Details |
|-----------|---------|
| **Shell** | zsh + oh-my-zsh (robbyrussell), autosuggestions, syntax-highlighting, completions |
| **Terminal** | tmux (C-a prefix, vi mode, mouse, GPU monitoring in status bar) |
| **Git** | SSH commit signing, LFS, pretty graph alias |
| **Tools** | fzf, ripgrep, fd, neovim, nvm/node, cloudflared |
| **ML** | miniconda3, CUDA auto-detection, HuggingFace/PyTorch/pip cache management |
| **AI** | Claude Code CLI |
| **OS** | Ubuntu 22.04 (primary), RHEL/CentOS/Rocky (secondary) — auto-detected |

## Quick Start

### Option A: Bare Metal / HPC

```bash
git clone https://github.com/qunzhongwang/dotfiles.git ~/dotfiles
cd ~/dotfiles
cp .env.example ~/.env
vim ~/.env                    # fill in your tokens
bash install.sh               # installs everything
exec zsh                      # switch to new shell
```

### Option B: Docker (Build Locally + Push to GHCR)

This is the recommended workflow for vast.ai, autodl, and other GPU clouds.

#### 1. Build the image

```bash
cd ~/dotfiles
docker build -f docker/Dockerfile.ubuntu -t ghcr.io/qunzhongwang/ml-env:latest .
```

#### 2. Test locally

```bash
# With .env file
docker run --rm -it --gpus all --env-file .env ghcr.io/qunzhongwang/ml-env:latest

# With bare env vars (simulates vast.ai/autodl)
docker run --rm -it --gpus all \
  -e GITHUB_TOKEN=ghp_xxx \
  -e HF_TOKEN=hf_xxx \
  -e WANDB_API_KEY=xxx \
  ghcr.io/qunzhongwang/ml-env:latest
```

#### 3. Push to GitHub Container Registry (GHCR)

```bash
# Login to GHCR (one-time)
echo "$GITHUB_TOKEN" | docker login ghcr.io -u qunzhongwang --password-stdin

# Push
docker push ghcr.io/qunzhongwang/ml-env:latest

# Optional: tag with date for versioning
docker tag ghcr.io/qunzhongwang/ml-env:latest ghcr.io/qunzhongwang/ml-env:$(date +%Y%m%d)
docker push ghcr.io/qunzhongwang/ml-env:$(date +%Y%m%d)
```

#### 4. Use on autodl / vast.ai

**autodl:**
1. Create instance → select "Custom Image" → enter `ghcr.io/qunzhongwang/ml-env:latest`
2. In the environment variables section, add:
   - `GITHUB_TOKEN` = your GitHub PAT
   - `HF_TOKEN` = your HuggingFace token
   - `WANDB_API_KEY` = your W&B API key
3. Start the instance — you'll land in a fully configured zsh shell
4. To redirect caches to the data disk:
   ```bash
   bash ~/dotfiles/setup-disk.sh /root/autodl-tmp  # or wherever autodl mounts data
   exec zsh
   ```

**vast.ai:**
1. Select "Custom Docker Image" → enter `ghcr.io/qunzhongwang/ml-env:latest`
2. Under "Environment Variables", add your tokens (same as autodl)
3. Connect via SSH — environment is ready
4. To redirect caches:
   ```bash
   bash ~/dotfiles/setup-disk.sh /workspace  # vast.ai typically mounts here
   exec zsh
   ```

## Repo Structure

```
dotfiles/
├── install.sh                 # Main entrypoint — run this on any fresh machine
├── setup-disk.sh              # Phase 2: redirect caches to persistent disk
├── .env.example               # Secret template (committed, safe)
│
├── config/                    # Dotfiles (symlinked to ~/.<name>)
│   ├── zshrc                  #   → ~/.zshrc
│   ├── bashrc                 #   → ~/.bashrc (auto-switches to zsh)
│   ├── tmux.conf              #   → ~/.tmux.conf
│   ├── gitconfig              #   → ~/.gitconfig
│   ├── gitignore_global       #   → ~/.gitignore_global
│   └── condarc                #   → ~/.condarc
│
├── scripts/                   # Modular install scripts
│   ├── detect-os.sh           #   OS detection (apt vs dnf)
│   ├── install-packages.sh    #   System packages
│   ├── install-tools.sh       #   User tools (omz, fzf, nvm, conda, claude)
│   ├── link-dotfiles.sh       #   Symlink config/* → ~/.*
│   └── clone-repos.sh         #   Clone private repos if token available
│
└── docker/                    # Container support
    ├── Dockerfile.ubuntu      #   nvidia/cuda:12.6.3 + Ubuntu 22.04
    ├── Dockerfile.rhel        #   nvidia/cuda:12.6.3 + Rocky Linux 9
    └── entrypoint.sh          #   Runtime secret injection
```

## Secrets Management

Secrets are **never baked into the Docker image**. They reach the container at runtime via one of three methods:

| Method | When to Use | Example |
|--------|------------|---------|
| `.env` file | Local dev, HPC, `docker run --env-file` | `docker run --env-file .env ...` |
| Bare env vars | vast.ai, autodl (set in cloud UI) | `-e GITHUB_TOKEN=ghp_xxx` |
| Mounted file | Advanced / CI | `-v /secrets/.env:/root/.env:ro` |

All three converge to the same result: `$GITHUB_TOKEN`, `$HF_TOKEN`, etc. are available in the shell.

### Available Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `GITHUB_TOKEN` | For private repos | Clone routines and other private repos, git credential helper |
| `HF_TOKEN` | For gated models | Download gated HuggingFace models (Llama, etc.) |
| `WANDB_API_KEY` | For experiment tracking | Auto-generates `~/.netrc` for wandb login |
| `GITHUB_USER` | No (default: `qunzhongwang`) | GitHub username for repo cloning |
| `DISK` | No (default: `$HOME`) | Persistent disk path for cache redirect |
| `WORKSPACE_DIR` | No (default: `~/wp`) | Where repos are cloned |

## Two-Phase Cache System

### Phase 1: Bootstrap (automatic)

Everything works locally in `$HOME/.cache/`. No persistent disk needed.

```
$HOME/.cache/huggingface/    ← HF_HOME
$HOME/.cache/torch/          ← TORCH_HOME
$HOME/.cache/pip/            ← PIP_CACHE_DIR
$HOME/.cache/uv/             ← UV_CACHE_DIR
```

### Phase 2: Persistent Disk (manual, one command)

After mounting a data disk, redirect all caches there:

```bash
# Set the disk path and run
bash ~/dotfiles/setup-disk.sh /path/to/datadisk

# What it does:
#   1. Creates $DISK/.cache/{huggingface,torch,pip,uv,vllm}
#   2. Creates $DISK/.conda/{envs,pkgs}
#   3. Migrates existing ~/.cache contents (rsync, safe)
#   4. Symlinks ~/.cache → $DISK/.cache
#   5. Updates .condarc (prepends $DISK paths, keeps originals as fallback)
#   6. Saves DISK= to ~/.env

exec zsh  # reload shell to pick up changes
```

**Common disk paths by provider:**
| Provider | Typical Data Disk |
|----------|------------------|
| autodl | `/root/autodl-tmp` or `/root/autodl-fs` |
| vast.ai | `/workspace` |
| Lambda | `/home/ubuntu/data` |
| HPC (SLURM) | `/scratch/...` or project-specific |

The script is **idempotent** — safe to run multiple times. It detects existing symlinks and skips if already configured.

## Updating

After changing dotfiles in the repo:

```bash
cd ~/dotfiles
git pull                      # get latest changes
bash scripts/link-dotfiles.sh # re-link (existing backups preserved)
exec zsh                      # reload
```

To add new tools, edit `scripts/install-tools.sh` and re-run:

```bash
bash scripts/install-tools.sh  # skips already-installed tools
```

## Building for RHEL / CentOS

```bash
docker build -f docker/Dockerfile.rhel -t ghcr.io/qunzhongwang/ml-env:rhel .
docker push ghcr.io/qunzhongwang/ml-env:rhel
```

## install.sh Options

```bash
bash install.sh               # Full install (needs root for system packages)
bash install.sh --no-system   # Skip system packages (no root needed)
```

Use `--no-system` when system packages are already installed (e.g., re-running after a `git pull`, or on a managed HPC node where you can't `apt install`).

## Aliases

| Alias | Expands To |
|-------|-----------|
| `w` | `cd $WORKSPACE_DIR` |
| `wv` | `cd $WORKSPACE_DIR/reason-vlm` |
| `wvr` | `cd $WORKSPACE_DIR/reason-vlm/reason-vlm-rl` |
| `wve` | `cd $WORKSPACE_DIR/reason-vlm/reason-vlm-eval` |
| `wr` | `cd $WORKSPACE_DIR/routines` |
| `wr-vllm` | `cd $WORKSPACE_DIR/routines/subroutine_vllm` |

## End-to-End Example: autodl with GHCR

```bash
# === On your local machine / HPC (one-time) ===

# 1. Build and push
cd ~/dotfiles
docker build -f docker/Dockerfile.ubuntu -t ghcr.io/qunzhongwang/ml-env:latest .
echo "$GITHUB_TOKEN" | docker login ghcr.io -u qunzhongwang --password-stdin
docker push ghcr.io/qunzhongwang/ml-env:latest

# === On autodl ===

# 2. Create instance with image: ghcr.io/qunzhongwang/ml-env:latest
#    Set env vars in autodl UI:
#      GITHUB_TOKEN=ghp_xxx
#      HF_TOKEN=hf_xxx
#      WANDB_API_KEY=xxx

# 3. SSH into instance — you're in zsh with full environment
#    oh-my-zsh ✓  fzf ✓  tmux ✓  conda ✓  claude ✓

# 4. Redirect caches to data disk
bash ~/dotfiles/setup-disk.sh /root/autodl-tmp
exec zsh

# 5. Clone your private repos (auto if GITHUB_TOKEN is set)
bash ~/dotfiles/scripts/clone-repos.sh

# 6. Start working
conda create -n myenv python=3.11
conda activate myenv
pip install torch transformers vllm
```
