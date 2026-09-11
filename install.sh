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
  Darwin) OS=macos ;;
  Linux)  OS=arch ;;
  *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
echo "==> detected OS: $OS"

# --- 1. packages -------------------------------------------------------------
if [[ "$OS" == arch ]]; then
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

# --- 2. zsh: oh-my-zsh + plugins ---------------------------------------------
# .zshrc is checked into this repo (zsh/.zshrc), static — no more
# generate-then-sed. Same oh-my-zsh custom-plugin clone step both OSes.
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
[[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

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
declare -A FILES=(
  ["zsh/.zshrc"]="$HOME/.zshrc"
  ["zsh/.zshenv"]="$HOME/.zshenv"
  ["zsh/.zprofile"]="$HOME/.zprofile"
  ["git/.gitconfig"]="$HOME/.gitconfig"
)
for src in "${!FILES[@]}"; do
  dest="${FILES[$src]}"
  if [[ -e "$dest" && ! -f "$dest.bak.$(date +%s)" ]]; then
    cp -p "$dest" "$dest.bak.$(date +%s)" 2>/dev/null || true
    echo "backed up existing $dest"
  fi
  cp "$(pwd)/$src" "$dest"
  echo "copied $src -> $dest"
done

# default shell -> zsh
[[ "$SHELL" == */zsh ]] || chsh -s "$(command -v zsh)"

# --- 5. hardware-specific setup (Arch only) ----------------------------------
if [[ "$OS" == arch ]]; then
  ./hardware/check-thinkpad-t14.sh || echo "hardware setup skipped/failed, see above"
fi

echo "done."
