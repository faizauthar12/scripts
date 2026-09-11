# Login-shell-only extras.

if [[ "$(uname -s)" == Darwin ]]; then
  # Added by Toolbox App
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"

  # Added by OrbStack: command-line tools and integration
  # This won't be added again if you remove it.
  source ~/.orbstack/shell/init.zsh 2>/dev/null || :

  export PYENV_ROOT="$HOME/.pyenv"
  [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - zsh)"

  # Added by Antigravity CLI installer
  export PATH="$HOME/.local/bin:$PATH"

  # ssh-agent + Keychain fallback (no gnome-keyring equivalent on macOS)
  if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519 2>/dev/null
  fi
fi
