#!/usr/bin/env bash
# T14 Gen1 (Intel) specific setup. Source: Arch Wiki
# https://wiki.archlinux.org/title/Lenovo_ThinkPad_T14/T14s_(Intel)_Gen_1
#
# ponytail: DMI table has no confirmed Gen1 machine-type codes on the wiki
# page (empty PCI/USB-ID column), so this checks the product string instead
# of guessing a codes. Verify Gen via PSREF (linked in README) if unsure.
set -euo pipefail

product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)"
version="$(cat /sys/class/dmi/id/product_version 2>/dev/null || echo unknown)"

echo "Detected board: product_name='$product' product_version='$version'"

if [[ "$product" != *"ThinkPad T14"* ]]; then
  echo "WARNING: this doesn't look like a ThinkPad T14. Skipping T14-specific setup." >&2
  echo "Run 'sudo dmidecode -t baseboard' and check PSREF to confirm the exact model/gen." >&2
  exit 1
fi

echo "-> ThinkPad T14 confirmed. Installing Gen1-known packages..."
sudo pacman -S --needed --noconfirm \
  sof-firmware \
  acpi_call-dkms \
  power-profiles-daemon

sudo systemctl enable --now power-profiles-daemon.service

echo "modules-load.d: enabling acpi_call at boot"
echo acpi_call | sudo tee /etc/modules-load.d/acpi_call.conf >/dev/null
sudo modprobe acpi_call || true

cat <<'EOF'

Manual steps (can't be scripted — do these in firmware/BIOS):
  1. Update BIOS/firmware BEFORE touching Secure Boot keys.
     Deleting keys on old firmware can brick the mainboard.
  2. Set BIOS > Config > Power > Sleep = "Linux" for working S3 suspend.
  3. If GPU/CPU throttles at ~57C on battery, switch to performance mode
     (see aliases pp-eco / pp-bal / pp-perf in .zshenv, or raw ACPI calls
     below if power-profiles-daemon isn't available):
       economy:     echo '\_SB.PCI0.LPCB.EC._Q6F' | sudo tee /proc/acpi/call
       balanced:    echo '\_SB.PCI0.LPCB.EC._Q6E' | sudo tee /proc/acpi/call
       performance: echo '\_SB.PCI0.LPCB.EC._Q6D' | sudo tee /proc/acpi/call
  4. Check turbo boost is on: cat /sys/devices/system/cpu/intel_pstate/no_turbo
     (0 = enabled, 1 = disabled -> reset BIOS to defaults)
EOF
