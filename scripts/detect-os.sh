#!/bin/bash
# =============================================================================
# Detect OS and set package manager variables
# Usage: source this file — sets DISTRO, PKG_MGR, PKG_INSTALL
# =============================================================================

DISTRO="unknown"
PKG_MGR=""
PKG_INSTALL=""

if [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      DISTRO="$ID"
      PKG_MGR="apt-get"
      PKG_INSTALL="apt-get install -y"
      ;;
    rhel|centos|rocky|almalinux|fedora)
      DISTRO="$ID"
      PKG_MGR="dnf"
      PKG_INSTALL="dnf install -y"
      ;;
    *)
      echo "WARNING: Unsupported distro '$ID'. Package installation may fail."
      ;;
  esac
else
  echo "WARNING: /etc/os-release not found. Cannot detect OS."
fi

echo "Detected OS: $DISTRO (package manager: ${PKG_MGR:-none})"
