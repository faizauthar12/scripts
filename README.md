# dotfiles2

Fresh-machine bootstrap for Arch Linux, target: work laptop, Lenovo ThinkPad
T14 Gen1 (Intel). Flow inspired by [akhilnarang/scripts](https://github.com/akhilnarang/scripts),
scoped to one distro since that's the only real target (YAGNI — add distro
branches later if actually needed, not before).

## Layout

```
install.sh                     # entry point: packages -> omz -> symlinks -> hardware
zsh/.zshenv                    # everything except theme/plugins (env, PATH, options, aliases)
hardware/check-thinkpad-t14.sh # T14 Gen1 detection + quirks from Arch Wiki
packages/pacman.txt            # explicit official-repo packages (pacman -Qqen)
packages/aur.txt                # explicit AUR packages (pacman -Qqem), incl.
                                # go, rust, jetbrains (rustrover etc.), android-studio
```

## Usage

```
git clone <this repo> ~/dotfiles2 && cd ~/dotfiles2
./install.sh
```

Re-run anytime — symlinking backs up existing files (`*.bak.<timestamp>`),
`pacman -S --needed` / `yay -S --needed` skip what's already installed.

Package lists were dumped from an existing machine. Prune
`packages/pacman.txt` / `packages/aur.txt` before running on a machine that
shouldn't get everything.

## zsh: .zshrc vs .zshenv

No static `.zshrc` in this repo. `install.sh` runs the stock oh-my-zsh
installer (generates the default template `.zshrc` — same as a manual fresh
install) and then `sed`s two lines in place: `ZSH_THEME` -> `agnoster`,
`plugins=(git)` -> `git archlinux systemd zsh-autosuggestions fzf zsh-syntax-highlighting`
(`zsh-syntax-highlighting` last — its own docs require it to be the last
plugin sourced). The two custom plugins are `git clone`d exactly as their
own `INSTALL.md` (Oh My Zsh section) lists, into
`~/.oh-my-zsh/custom/plugins/`. This keeps the sed commands in `install.sh`
as the single source of truth instead of a checked-in file that can drift
from what the installer actually generates.

Everything else — env vars, PATH, history, options, aliases — lives in
`.zshenv`, since that's sourced for *every* zsh invocation (login,
interactive, non-interactive scripts/`zsh -c`). Interactive-only bits inside
it (options, bindkeys, aliases) are gated behind `[[ $- == *i* ]]` so
non-interactive shells don't pay for them.

## Hardware notes — ThinkPad T14 Gen1 (Intel)

Source: [Arch Wiki — Lenovo ThinkPad T14/T14s (Intel) Gen 1](https://wiki.archlinux.org/title/Lenovo_ThinkPad_T14/T14s_(Intel)_Gen_1).
The wiki's hardware table has no confirmed Gen1 machine-type/PCI-ID codes, so
`check-thinkpad-t14.sh` checks `/sys/class/dmi/id/product_name` for
`"ThinkPad T14"` rather than guessing a code — cross-check your exact model
against [PSREF](https://psref.lenovo.com/) if you need to be sure it's Gen1
specifically vs Gen2+.

What the script handles:
- `sof-firmware` — this board needs Sound Open Firmware for audio to work
- `acpi_call-dkms` + loads the module at boot — needed for manual power-mode
  ACPI calls
- `power-profiles-daemon`, enabled as a service — the normal way to flip
  power modes (`pp-eco`/`pp-bal`/`pp-perf` aliases in `.zshenv`)

What it can only print (BIOS-side, can't be scripted):
- **Secure Boot**: don't delete/enroll your own Secure Boot keys before
  updating firmware — doing so on old firmware can brick the mainboard,
  fixable only by replacing it
- **Suspend**: set BIOS `Config > Power > Sleep = Linux` for working S3
  suspend
- **Throttling**: on battery, GPU throttles ~57°C unless in performance
  mode; check Turbo Boost via
  `cat /sys/devices/system/cpu/intel_pstate/no_turbo` (`0` = enabled)
