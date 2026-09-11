#!/usr/bin/env bash
# Fresh-machine bootstrap for Arch Linux. Idempotent: re-run any time.
# Style/flow lifted from https://github.com/akhilnarang/scripts, scoped down
# to one distro (Arch) since that's the only real target — see README.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# --- 1. packages -------------------------------------------------------------
sudo pacman -Syu --needed --noconfirm - < packages/pacman.txt

if ! command -v yay >/dev/null; then
  echo "yay not found, bootstrapping it..."
  sudo pacman -S --needed --noconfirm base-devel git
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  (cd /tmp/yay-bin && makepkg -si --noconfirm)
fi
yay -S --needed --noconfirm - < packages/aur.txt
