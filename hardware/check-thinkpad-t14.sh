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
