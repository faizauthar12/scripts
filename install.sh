#!/usr/bin/env bash
# Fresh-machine bootstrap. Idempotent: re-run any time.
# Style/flow lifted from https://github.com/akhilnarang/scripts.
# Two targets, detected via `uname -s`:
#   Linux  -> Arch Linux (work laptop, ThinkPad T14)
#   Darwin -> macOS (personal MacBook)
# One shared dotfiles set (zsh/, git/) with inline `uname` conditionals for
# the handful of genuinely OS-specific lines — see zsh/.zshenv. Config files
# are copied into place (not symlinked), so ~/.zshrc etc. are real files a
# machine can diverge from without corrupting this repo.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

case "$(uname -s)" in
  Darwin)
    OS=macos
    ;;
  Linux)
    if [[ -r /etc/os-release ]] && . /etc/os-release && [[ "$ID" == arch || "${ID_LIKE:-}" == *arch* ]]; then
      OS=arch
    else
      echo "unsupported Linux distro: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-${ID:-unknown}}") — this script targets Arch only" >&2
      exit 1
    fi
    ;;
  *)
    echo "unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac
echo "==> detected OS: $OS"

# --- 1. packages -------------------------------------------------------------
if [[ "$OS" == arch ]]; then
  # [core]/[extra] ship enabled by default; [multilib] ships commented out —
  # needed for lib32-* packages installed conditionally by hardware/detect-gpu.sh.
  # Idempotent: strips a leading `#` from the [multilib] line and the one
  # right after it; a no-op if already uncommented.
  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "enabling [multilib] repository in /etc/pacman.conf..."
    sudo sed -i '/^#\[multilib\]/,+1s/^#//' /etc/pacman.conf
  fi

  sudo pacman -Syu --needed --noconfirm - < packages/pacman.txt

  if ! command -v yay >/dev/null; then
    echo "yay not found, bootstrapping it..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
  fi
  yay -S --needed --noconfirm - < packages/aur.txt

elif [[ "$OS" == macos ]]; then
  if ! command -v brew >/dev/null; then
    echo "homebrew not found, bootstrapping it..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  while read -r tap; do
    [[ -z "$tap" ]] && continue
    brew tap "$tap"
  done < packages/brew-taps.txt
  brew install $(cat packages/brew.txt)
  brew install --cask $(cat packages/brew-cask.txt)
fi

# --- 2. zsh: oh-my-zsh generates .zshrc, then patch theme/plugins in place --
# Let oh-my-zsh's own installer generate the stock .zshrc from its template
# (only runs if ~/.zshrc doesn't exist) — no static .zshrc checked into this
# repo, so we never fight the installer's own template management. `sed -i.bak`
# (portable across BSD sed on macOS and GNU sed on Arch) patches theme/plugins
# in place; zsh-syntax-highlighting must be the LAST plugin sourced (its own
# docs require it). zsh/.zshenv (env, PATH, options, aliases — shared across
# both machines) is appended as a source line if not already present.
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

sed -i.bak 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$HOME/.zshrc"
if [[ "$OS" == macos ]]; then
  sed -i.bak 's/^plugins=(git)$/plugins=(git zsh-autosuggestions fzf macos zsh-syntax-highlighting)/' "$HOME/.zshrc"
else
  sed -i.bak 's/^plugins=(git)$/plugins=(git archlinux systemd zsh-autosuggestions fzf zsh-syntax-highlighting)/' "$HOME/.zshrc"
fi
rm -f "$HOME/.zshrc.bak"
grep -qxF 'source ~/.zshenv' "$HOME/.zshrc" || echo 'source ~/.zshenv' >> "$HOME/.zshrc"

# --- 3. ssh key + agent -------------------------------------------------------
if [[ "$OS" == arch ]]; then
  # gnome-keyring/gcr-4 are here as dependencies of other packages on this
  # machine (not explicit), and the socket that wires SSH_AUTH_SOCK to it is a
  # user-level enable, not a package default — both need doing explicitly.
  systemctl --user enable --now gcr-ssh-agent.socket

  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    mkdir -p -m 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "faizauthar@gmail.com" -f "$HOME/.ssh/id_ed25519"
  fi

  cat <<'EOF'

SSH key ready. gcr-ssh-agent auto-discovers keys in ~/.ssh — no ssh-add
needed. First use (first git push / ssh) pops a GUI passphrase prompt with
an "automatically unlock" checkbox; tick it once and gnome-keyring unlocks
the key at every login after that (same as this machine, via PAM in
/etc/pam.d/gdm-password — shipped by the gdm package, nothing to script).
EOF

elif [[ "$OS" == macos ]]; then
  # macOS: no gnome-keyring here. ssh-agent + Keychain via the ssh-add
  # fallback already baked into zsh/.zprofile (eval ssh-agent, ssh-add the
  # key if SSH_AUTH_SOCK isn't already set).
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    mkdir -p -m 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "faizauthar@gmail.com" -f "$HOME/.ssh/id_ed25519"
  fi
fi

# --- 4. dotfiles: copy into place (not symlink) ------------------------------
# .zshrc is NOT here — it's generated by oh-my-zsh + sed-patched in step 2.
for pair in "zsh/.zshenv:$HOME/.zshenv" \
            "zsh/.zprofile:$HOME/.zprofile" "git/.gitconfig:$HOME/.gitconfig"; do
  src="${pair%%:*}"; dest="${pair#*:}"
  if [[ -e "$dest" ]] && cmp -s "$src" "$dest"; then
    echo "$dest already matches repo, skipping"
    continue
  fi
  if [[ -e "$dest" ]]; then
    cp -p "$dest" "$dest.bak.$(date +%s)" 2>/dev/null || true
    echo "$dest differs from repo copy — backed up existing content, overwriting"
  fi
  cp "$(pwd)/$src" "$dest"
  echo "copied $src -> $dest"
done

# default shell -> zsh
[[ "$SHELL" == */zsh ]] || chsh -s "$(command -v zsh)"

# --- 5. hardware-specific setup (Arch only) ----------------------------------
if [[ "$OS" == arch ]]; then
  ./hardware/detect-gpu.sh || echo "GPU driver detection skipped/failed, see above" >&2
  ./hardware/check-thinkpad-t14.sh || echo "hardware setup skipped/failed, see above"
fi

# --- 6. AI tooling: Hermes, Claude Code plugins/MCP, rtk, caveman -----------
# Hermes Agent (CLI/gateway/TUI) — official cross-platform one-liner:
# https://github.com/NousResearch/hermes-agent
if command -v hermes >/dev/null; then
  echo "==> hermes CLI already installed, running hermes update"
  hermes update --yes || echo "hermes update failed, continuing" >&2
else
  echo "==> installing Hermes Agent"
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash || echo "Hermes install failed, continuing" >&2
fi

# Hermes Desktop: AUR package (hermes-agent-desktop, packages/aur.txt) already
# installs the native app on Arch. On macOS there's no equivalent cask (yet),
# so fetch the official prebuilt DMG and install it into /Applications, per
# apps/desktop/README.md in the hermes-agent repo (installers are built and
# uploaded to GitHub Releases / the Hermes Desktop website manually, not via
# brew). Alternative documented upstream: `hermes desktop` builds against
# your existing CLI install instead of using a prebuilt installer.
if [[ "$OS" == macos ]]; then
  if [[ -d "/Applications/Hermes.app" ]]; then
    echo "==> Hermes.app already in /Applications, skipping desktop install"
  else
    echo "==> downloading Hermes Desktop"
    if DMG=$(mktemp -t hermes-setup).dmg && \
       curl -fsSL "https://hermes-assets.nousresearch.com/Hermes-Setup.dmg" -o "$DMG"; then
      MOUNT=$(hdiutil attach "$DMG" -nobrowse -quiet | tail -1 | awk '{print $NF}')
      APP_SRC=$(find "$MOUNT" -maxdepth 1 -iname "*.app" | head -1)
      if [[ -n "$APP_SRC" ]]; then
        cp -R "$APP_SRC" /Applications/
        echo "installed $(basename "$APP_SRC") -> /Applications/"
      else
        echo "no .app bundle found in DMG, mounted at $MOUNT — install manually" >&2
      fi
      hdiutil detach "$MOUNT" -quiet || true
      rm -f "$DMG"
    else
      echo "Hermes Desktop download failed, continuing" >&2
    fi
  fi
fi

# Claude Code CLI is installed via the package lists already (aur.txt /
# brew-cask.txt: claude-code) — this section only wires plugins + MCP once
# the CLI is present.
if ! command -v claude >/dev/null; then
  echo "claude CLI not found (expected from package install above), skipping plugin setup" >&2
else
  # Claude Code plugins — non-interactive CLI form, not the two-message
  # `/plugin` slash-command flow meant for interactive use.
  # ponytail: https://github.com/DietrichGebert/ponytail
  claude plugin marketplace add DietrichGebert/ponytail || true
  claude plugin install ponytail@ponytail || true

  # humanizer: https://github.com/blader/humanizer
  claude plugin marketplace add blader/humanizer || true
  claude plugin install humanizer@humanizer || true

  # claude-code-workflows: https://github.com/wshobson/agents
  claude plugin marketplace add wshobson/agents || true
  claude plugin install backend-development@claude-code-workflows || true
  claude plugin install python-development@claude-code-workflows || true
  claude plugin install documentation-standards@claude-code-workflows || true
  claude plugin install code-documentation@claude-code-workflows || true

  # Context7 MCP server — remote HTTP transport, per
  # https://context7.com/docs/clients/claude-code
  # CONTEXT7_API_KEY is exported from zsh/.zshenv; export it in your shell
  # before running this script on a machine that doesn't have it.
  if ! claude mcp get context7 >/dev/null 2>&1; then
    if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
      claude mcp add --scope user --header "Authorization: Bearer ${CONTEXT7_API_KEY}" \
        --transport http context7 https://mcp.context7.com/mcp || echo "context7 MCP registration failed, continuing" >&2
    else
      echo "CONTEXT7_API_KEY not set — skipping context7 MCP registration" >&2
    fi
  fi
fi

# rtk (CLI proxy to minimize LLM token consumption) — package install already
# happened above (rtk-bin on Arch, rtk on brew); wire its Claude Code hook.
# https://www.rtk-ai.app/
if command -v rtk >/dev/null && command -v claude >/dev/null; then
  rtk init -g --auto-patch || echo "rtk init failed, see above" >&2
fi

# caveman (context-compression proxy for coding agents) — npm CLI front-end +
# signed native binaries fetched by `caveman setup --install`, per
# https://github.com/JuliusBrussee/caveman
if ! command -v caveman >/dev/null; then
  # npm's configured prefix (e.g. ~/.local via ~/.npmrc) can point at a
  # directory whose lib/ subdir doesn't exist yet — `npm install -g` then
  # fails with ENOENT before it ever reaches the network. Ensure it exists.
  mkdir -p "$(npm config get prefix)/lib" 2>/dev/null || true
  npm install -g @caveman-ai/cli || echo "caveman-ai/cli npm install failed, continuing" >&2
fi
caveman setup --install || echo "caveman setup --install failed, see above" >&2

echo "done."
