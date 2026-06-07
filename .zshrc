# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="gtheme-dark"

# Plugins
plugins=(
  git
  docker
  kubectl
  node
  npm
  yarn
  python
  pip
  golang
  rust
  zsh-autosuggestions
  zsh-syntax-highlighting
  history-substring-search
  colored-man-pages
  extract
  web-search
)

# Platform detection
is_macos=false
[[ "$OSTYPE" == darwin* ]] && is_macos=true

# macOS-only plugins
if [[ "$is_macos" == true ]]; then
  plugins+=(brew macos copypath copyfile)
fi

# Enable grep color when the installed grep supports --color
if command grep --help 2>&1 | command grep -q -- '--color'; then
  alias grep='grep --color=auto'
fi

# Oh My Zsh
if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# History configuration
HISTSIZE=50000
SAVEHIST=50000
HISTFILE="$HOME/.zsh_history"
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt EXTENDED_HISTORY

# Key bindings for history search
if (( ${+widgets[history-substring-search-up]} )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi
bindkey '^R' history-incremental-search-backward

# Reload zshrc
alias reload='source ~/.zshrc'

# History
alias h='history'

# Copy to clipboard and print to terminal
alias -g yank='| tee /dev/tty | pbcopy'

# Git commit
alias gcm='git commit -m'

# Git stash including untracked files
alias gs='git stash -u'

# Git stash apply 
alias gsa='git stash apply'

# Git clean dry
alias gc-dry='git clean -nd'

# Git clean force
alias gc='git clean -fd'

# Support 256 color terminal
export TERM=xterm-256color

# Default editor (prefer nvim > vim > vi)
if command -v nvim >/dev/null 2>&1; then
  export EDITOR='nvim'
  export VISUAL='nvim'
elif command -v vim >/dev/null 2>&1; then
  export EDITOR='vim'
  export VISUAL='vim'
else
  export EDITOR='vi'
  export VISUAL='vi'
fi

# Github token from keychain or gh cli
if [[ "$is_macos" == true ]] && command -v security >/dev/null 2>&1; then
  token="$(security find-generic-password -s "GITHUB_TOKEN" -w 2>/dev/null || true)"
  [[ -n "$token" ]] && export GITHUB_TOKEN="$token"
elif [[ -z "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
  token="$(gh auth token 2>/dev/null || true)"
  [[ -n "$token" ]] && export GITHUB_TOKEN="$token"
fi
unset token

# AWS
export AWS_PROFILE=tradester-test
export AWS_REGION=us-east-1

# NVM
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# Prefer installed CLI tools
export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH=/Users/garrett/.opencode/bin:$PATH
