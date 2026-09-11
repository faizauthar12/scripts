#!/usr/bin/env zsh
# Everything except theme/plugins — those live in zsh/.zshrc (checked in,
# static, identical on both machines: oh-my-zsh + plugin list). .zshenv loads
# for every zsh invocation (login, interactive, script), so interactive-only
# bits (options, bindkeys, aliases) are gated behind the check at the bottom.
#
# Shared config lives unconditionally below. Anything genuinely OS-specific
# is gated on `uname -s` (Darwin vs Linux) inline, right next to the shared
# equivalent, so the two machines' env stays diffable at a glance instead of
# living in two separate files that drift apart.

# --- always-on: env vars, PATH ---------------------------------------------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export EDITOR="nvim"
export VISUAL="$EDITOR"
export PAGER="less"
export LANG="en_US.UTF-8"

typeset -U path
path=("$HOME/.local/bin" $path)
export PATH

export HISTFILE="$XDG_STATE_HOME/zsh/history"
export HISTSIZE=99999999
export SAVEHIST=99999999
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

# --- Go: shared private-module config, OS-specific GOPATH bin -------------
export GOPRIVATE=github.com/faizauthar12/*,github.com/dbo-id/*,bitbucket.org/admin_dbo/*,github.com/Aturjadwal/*,github.com/21strive/*
export GONOPROXY=$GOPRIVATE
export GONOSUMDB=$GOPRIVATE

if [[ "$(uname -s)" == Darwin ]]; then
  # Go (Homebrew go ships its own GOPATH resolution)
  export PATH="$PATH:$(go env GOPATH)/bin"

  # Java (Homebrew openjdk isn't symlinked into /usr/libexec/java_home by default)
  export JAVA_HOME=/opt/homebrew/opt/openjdk
  export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

  export LIBRARY_PATH="/opt/homebrew/lib"
  export CPATH="/opt/homebrew/include"
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
else
  export GO_PATH=~/go
  export PATH="$PATH:$GO_PATH/bin"
fi

# Flutter
export PATH="$PATH:$HOME/bin/flutter/bin"
if [[ "$(uname -s)" == Darwin ]]; then
  export PATH="$HOME/fvm/bin:$PATH"  # fvm, flutter version manager
fi

# Android home path
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# SSH agent socket
if [[ "$(uname -s)" == Darwin ]]; then
  # macOS: no gnome-keyring; ssh-agent + ssh-add fallback (see zsh/.zprofile)
  :
else
  # Linux: gcr-ssh-agent.socket (enabled by install.sh) owns SSH_AUTH_SOCK
  export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh
fi

export USE_CCACHE=1
export CCACHE_DIR=~/ccache
if [[ "$(uname -s)" == Darwin ]]; then
  export CCACHE_EXEC=/usr/bin/ccache
fi

# sccache
export SCCACHE_DIR="$HOME/.cache/sccache"
export SCCACHE_CACHE_SIZE="150G"

# Cargo
export CARGO_HOME=$HOME/.cargo
export PATH="$CARGO_HOME/bin:$PATH"
if [[ "$(uname -s)" == Darwin ]]; then
  export CARGO_BUILD_JOBS=2
fi

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if [[ "$(uname -s)" == Darwin ]]; then
  alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# uv
export PATH="$HOME/.local/bin:$PATH"

if [[ "$(uname -s)" == Darwin ]]; then
  # Added by LM Studio CLI (lms)
  export PATH="$PATH:$HOME/.lmstudio/bin"
  # End of LM Studio CLI section

  . "$HOME/.local/bin/env"
  export PATH=~/.npm-global/bin:$PATH

  # Added by Antigravity CLI installer / cua-driver-rs installer (same path, both append it)
  export PATH="$HOME/.local/bin:$PATH"

  export CONTEXT7_API_KEY="ctx7sk-76eaf396-a26d-44de-97be-215574b2cb68"
fi

# --- interactive-only below --------------------------------------------------
[[ $- == *i* ]] || return 0

setopt AUTO_CD EXTENDED_GLOB
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_VERIFY SHARE_HISTORY
setopt INTERACTIVE_COMMENTS
bindkey -e

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias ..='cd ..'
alias g='git'

if [[ "$(uname -s)" == Darwin ]]; then
  # bun completions
  [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

  # Mole shell completion
  if output="$(mole completion zsh 2>/dev/null)"; then eval "$output"; fi

  eval "$(pyenv init - zsh)"
else
  # thinkpad power-profile switcher via power-profiles-daemon
  # see hardware/check-thinkpad-t14.sh for the raw ACPI fallback
  alias pp-eco='powerprofilesctl set power-saver'
  alias pp-bal='powerprofilesctl set balanced'
  alias pp-perf='powerprofilesctl set performance'
fi
