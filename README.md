# dotfiles2

Fresh-machine bootstrap for two targets, detected via `uname -s` in
`install.sh`:

- **Linux -> Arch** — work laptop, Lenovo ThinkPad T14 Gen1 (Intel)
- **Darwin -> macOS** — personal MacBook

Flow inspired by [akhilnarang/scripts](https://github.com/akhilnarang/scripts).
One script, one dotfiles set: shared config lives unconditionally, genuinely
OS-specific lines are gated inline with `uname -s` checks (see `zsh/.zshenv`)
so the two machines' env stays diffable in one file instead of drifting apart
across separate ones.

## Layout

```
install.sh                     # entry point: packages -> zsh -> ssh -> dotfiles -> hardware -> AI tools
check.sh                       # bash -n / zsh -n syntax check over every script + dotfile in the repo
zsh/.zshenv                    # shared env/PATH/options/aliases, OS-specific lines gated by `uname -s`
zsh/.zshrc                     # shared oh-my-zsh + plugin list (Darwin/Linux plugin sets differ inline)
zsh/.zprofile                  # login-shell extras (currently macOS-only blocks; Arch needs none yet)
git/.gitconfig                 # git identity, URL rewrites (ssh over https), git-lfs — shared
hardware/check-thinkpad-t14.sh # Arch/T14 Gen1 detection + quirks from Arch Wiki
packages/pacman.txt             # Arch: explicit official-repo packages (pacman -Qqen)
packages/aur.txt                 # Arch: explicit AUR packages (pacman -Qqem), incl.
                                 # go, rust, jetbrains (rustrover etc.), android-studio,
                                 # hermes-agent(-desktop), claude-code, rtk-bin
packages/brew.txt                # macOS: brew leaves (brew leaves), formula installs
packages/brew-cask.txt           # macOS: brew casks (brew list --cask), incl. claude-code
packages/brew-taps.txt           # macOS: third-party taps (brew tap)
```

## Usage

```
git clone <this repo> ~/dotfiles2 && cd ~/dotfiles2
./install.sh
```

`install.sh` detects the OS and only runs that branch's package-manager
steps; everything else (zsh, dotfiles, AI tooling) is shared. Re-run
anytime — `pacman -S --needed` / `yay -S --needed` / `brew install` skip
what's already installed, and dotfiles are backed up before being
overwritten (`*.bak.<timestamp>`).

Step 6 (AI tooling: Hermes, Claude Code plugins/MCP, rtk, caveman) is
fault-tolerant per-tool — one failed install/registration logs a warning to
stderr and the script keeps going, instead of `set -euo pipefail` aborting
the whole run over the least critical step.

Run `./check.sh` before committing to catch shell/zsh syntax errors — it
runs `bash -n`/`zsh -n` over every script and dotfile in the repo. Not
wired as an automatic git hook (opt-in only, since `core.hooksPath` isn't
itself versioned by git): `git config core.hooksPath scripts-hooks && ln -s
../../check.sh scripts-hooks/pre-commit` if you want it enforced locally.

**Dotfiles are copied into place, not symlinked** — `~/.zshrc` etc. are real
files a machine is free to diverge from locally without corrupting this
repo's copy; re-running `install.sh` re-copies the repo's version over
whatever's there (after backing it up).

Package lists were dumped from an existing machine. Prune
`packages/pacman.txt` / `packages/aur.txt` / `packages/brew*.txt` before
running on a machine that shouldn't get everything.

## zsh: shared file, `uname`-gated OS differences

No more generate-then-`sed`, no more separate per-OS file trees. `zsh/.zshrc`
is checked in statically (oh-my-zsh + theme + plugin list — Arch adds
`archlinux systemd`, macOS adds `macos`, both end with
`zsh-syntax-highlighting` since its own docs require it last).
`install.sh` clones the two custom plugins (`zsh-autosuggestions`,
`zsh-syntax-highlighting`) into `~/.oh-my-zsh/custom/plugins/` on both OSes.

`zsh/.zshenv` holds everything else — env vars, PATH, history, options,
aliases — sourced for *every* zsh invocation (login, interactive,
non-interactive scripts/`zsh -c`). Interactive-only bits (options, bindkeys,
aliases) are gated behind `[[ $- == *i* ]]`. Genuinely OS-specific lines
(Homebrew paths, `GOPATH` resolution, `gcr-ssh-agent` socket vs macOS
ssh-agent fallback, LM Studio/Antigravity PATH additions) sit inline next to
their shared equivalent behind `[[ "$(uname -s)" == Darwin ]]` checks, so a
`diff` against either machine's live `~/.zshenv` stays small.

`zsh/.zprofile` is login-shell-only extras; today that's exclusively macOS
blocks (Toolbox App, OrbStack, pyenv init, ssh-agent+Keychain fallback) since
Arch doesn't need any at the moment — the file structure supports adding an
Arch-only block the same way if that changes.

## Arch SSH + gnome-keyring

Matches how this machine actually works, confirmed by inspecting it live
(not the old `gnome-keyring-daemon --start --components=ssh` way — that's
superseded by `gcr-4`'s `gcr-ssh-agent`):

- `gnome-keyring` + `gcr-4` packages (in `packages/pacman.txt` — on this
  machine they're only pulled in as dependencies of other packages, so
  listed explicitly here instead of hoping that keeps happening)
- `systemctl --user enable --now gcr-ssh-agent.socket` — this is a
  user-level enable (symlink lives in `~/.config/systemd/user/`, not a
  package default), so `install.sh` does it explicitly. The socket sets
  `SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh` in the systemd user environment
  on activation; `.zshenv` also exports it directly as a fallback for
  shells started outside that session (gated to Linux)
- `ssh-keygen -t ed25519` generates a fresh key if `~/.ssh/id_ed25519`
  doesn't exist yet (this machine's key is an older RSA one — ed25519 is
  the current sane default for a new key, not a re-migration of the old one)
- keyring auto-unlock at login (`pam_gnome_keyring.so` in
  `/etc/pam.d/gdm-password`) ships with the `gdm` package itself — nothing
  to script there
- `gcr-ssh-agent` auto-discovers keys under `~/.ssh` on demand, no
  `ssh-add`/`~/.ssh/config` needed (this machine has neither) — first use
  pops a GUI passphrase prompt with a "remember" checkbox; that's the
  one-time manual step that can't be scripted

## macOS SSH

No gnome-keyring equivalent — `zsh/.zprofile` runs `ssh-agent -s` + `ssh-add`
if `SSH_AUTH_SOCK` isn't already set, same key (`ssh-keygen -t ed25519`,
generated by `install.sh` if missing).

`.zshenv` on this machine has `CONTEXT7_API_KEY` hardcoded (checked into
this repo as-is per explicit choice — this repo/remote is private).

## AI tooling — Hermes, Claude Code plugins/MCP, rtk, caveman

Part of `install.sh` (step 6), runs on both OSes; each tool installed per its
own official docs/repo:

- **Hermes Agent (CLI/gateway/TUI)** — official one-liner from
  [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent):
  `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`.
  Re-runs as `hermes update` if already installed.
- **Hermes Desktop** — on Arch, the `hermes-agent-desktop` AUR package
  (`packages/aur.txt`) covers it. On macOS there's no cask equivalent yet,
  so `install.sh` downloads the official `Hermes-Setup.dmg` from
  `hermes-assets.nousresearch.com` (per `apps/desktop/README.md` in that
  repo — installers are distributed from the Hermes Desktop website, not
  GitHub Releases assets), mounts it, and copies the `.app` bundle into
  `/Applications`. Documented alternative upstream: `hermes desktop`, which
  builds/launches against your existing CLI install instead.
- **Claude Code CLI** — installed via the package lists (`claude-code` in
  both `aur.txt` and `brew-cask.txt`); `install.sh` only wires plugins/MCP
  once it's present.
- **Claude Code plugins** — installed via the documented non-interactive CLI
  form (`claude plugin marketplace add <owner>/<repo>` + `claude plugin
  install <name>@<marketplace>`), not the two-message `/plugin` slash-command
  flow meant for interactive use:
  - [ponytail](https://github.com/DietrichGebert/ponytail)
  - [humanizer](https://github.com/blader/humanizer)
  - [claude-code-workflows](https://github.com/wshobson/agents) (backend-development, python-development, documentation-standards, code-documentation)
- **Context7 MCP** — registered per
  [context7.com/docs/clients/claude-code](https://context7.com/docs/clients/claude-code)
  as a remote HTTP MCP server (`claude mcp add --scope user --transport http
  ... https://mcp.context7.com/mcp`), authenticated via `CONTEXT7_API_KEY`.
- **rtk** — [rtk-ai.app](https://www.rtk-ai.app/), installed via the package
  lists (`rtk-bin` on Arch, `rtk` on Homebrew), wired into Claude Code's
  `PreToolUse` hook via its own `rtk init -g --auto-patch` (patches
  `~/.claude/settings.json`).
- **caveman** — [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman),
  installed via `npm install -g @caveman-ai/cli` then `caveman setup
  --install` (fetches and verifies the signed companion Go binaries into
  `~/.caveman/bin`), per the package's own README.

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
