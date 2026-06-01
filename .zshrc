# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Platform detection
is_macos=false
[[ "$OSTYPE" == darwin* ]] && is_macos=true

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

if [[ "$is_macos" == true ]]; then
  plugins+=(brew macos copypath copyfile)
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

# Aliases
if command grep --help 2>&1 | command grep -q -- '--color'; then
  alias grep='grep --color=auto'
fi
# Reload zshrc
alias reload='source ~/.zshrc'
# Clear screen
alias cls='clear'
# History
alias h='history'
# Copy to clipboard and print to terminal
alias -g yank='| tee /dev/tty | pbcopy'
# Git
alias gcm='git commit -m'
alias gstash='git stash -u'
alias gapply='git stash apply'
alias gclean-dry='git clean -nd'
alias gclean='git clean -fd'


# Env vars
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

# Path
export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH=/Users/garrett/.opencode/bin:$PATH
