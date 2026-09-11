#!/usr/bin/env bash
# GPU vendor detection + matching driver install (Arch only). Runs before
# hardware/check-thinkpad-t14.sh in install.sh since GPU vendor isn't
# T14-specific — any Arch machine this repo targets could have AMD, Intel,
# or NVIDIA graphics (or a hybrid of two).
#
# Reads /sys/bus/pci/devices directly (class 0x03xxxx = display controller,
# per the PCI class code spec) instead of shelling out to `lspci` — avoids
# depending on the `pciutils` package being installed, which isn't part of
# `base` on Arch. Standard PCI vendor IDs: 0x1002 AMD/ATI, 0x8086 Intel,
# 0x10de NVIDIA. See https://wiki.archlinux.org/title/Modalias for the
# vendor/device/class ID scheme this relies on.
set -euo pipefail

declare -a vendors=()
for dev in /sys/bus/pci/devices/*/; do
  class="$(cat "${dev}class" 2>/dev/null || echo 0x000000)"
  # top byte of class == 0x03 -> display controller (VGA/3D/other)
  [[ "$class" == 0x03* ]] || continue
  vendor="$(cat "${dev}vendor" 2>/dev/null || echo unknown)"
  vendors+=("$vendor")
done

if [[ ${#vendors[@]} -eq 0 ]]; then
  echo "no PCI display controller found under /sys/bus/pci/devices — skipping GPU driver install" >&2
  exit 0
fi

echo "detected GPU vendor ID(s): ${vendors[*]}"

has_amd=0 has_intel=0 has_nvidia=0
for v in "${vendors[@]}"; do
  case "$v" in
    0x1002) has_amd=1 ;;
    0x8086) has_intel=1 ;;
    0x10de) has_nvidia=1 ;;
  esac
done

pkgs=()
(( has_amd ))    && pkgs+=(vulkan-radeon lib32-vulkan-radeon radeontop)
(( has_intel ))  && pkgs+=(vulkan-intel lib32-vulkan-intel intel-gpu-tools)
(( has_nvidia )) && echo "NVIDIA GPU detected — install nvidia/nvidia-utils manually per https://wiki.archlinux.org/title/NVIDIA (proprietary driver choice not scripted here)" >&2

if [[ ${#pkgs[@]} -gt 0 ]]; then
  echo "installing GPU driver packages: ${pkgs[*]}"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"
else
  echo "no AMD/Intel GPU detected — nothing to install"
fi
