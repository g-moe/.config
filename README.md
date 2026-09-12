# Garrett's dotfiles

This repository contains personal workstation configuration for macOS and
Debian 13.

The repository is designed to live at `~/.dotfiles`. The top-level application
folders are the source of truth. The installer creates links to the individual
files and subfolders that each application needs; it does not link every
source folder as a whole.

## Repository map

```text
.
├── .agents/                Shared agent instructions and skills
├── .archive/               Archived files grouped by former application
├── .github/                GitHub templates and repository automation
├── .vscode/                Settings for working on this repository
├── arc/                    Arc routing configuration
├── claude/                 Claude Code settings
├── codex/.codex/           Codex settings and keybindings
├── ghostty/                Ghostty configuration and generated themes
├── images/                 Shared artwork used by the installer
├── karabiner/              Karabiner-Elements configuration
├── nvim/                   Neovim configuration and plugins
├── packages/
│   ├── agent-usage/        Agent subscription usage CLI
│   ├── installer/          Machine installer and installer tests
│   ├── lib/
│   │   ├── bash/           Reusable Bash libraries and CLI tools
│   │   └── ts/             Shared TypeScript library
│   ├── mac/                macOS tools and the mactop application
│   ├── raycast/            Raycast extensions and shared runner
│   ├── theming/            Theme generator and VS Code theme package
│   └── vscode-ext/         VSCodium extension source and tests
├── superfile/              Superfile configuration and theme
├── tmux/                   tmux configuration
├── vscode/user/            VS Code / VSCodium user settings
├── zsh/                    Zsh startup files
│
├── AGENTS.md               Instructions for agents editing this repository
├── package.json             Root commands and development dependencies
├── TODO.md                 Current work list
└── tsconfig.json            Root TypeScript project references
```

## Configuration folders

These folders contain application configuration, not installer logic.

| Folder          | Contents                                                                                        |
| --------------- | ----------------------------------------------------------------------------------------------- |
| `arc/`          | Arc's `StorableLinkRouting.json`. It stores Arc Space IDs and is used on macOS.                 |
| `claude/`       | Personal Claude Code settings.                                                                  |
| `codex/.codex/` | Personal Codex configuration and keybindings.                                                   |
| `ghostty/`      | Ghostty config and the light and dark generated themes.                                         |
| `images/`       | Shared Tux artwork and other installer assets.                                                  |
| `karabiner/`    | Karabiner-Elements keyboard remapping rules.                                                    |
| `nvim/`         | Neovim entry point, options, keymaps, plugin setup, and plugins.                                |
| `superfile/`    | Superfile config and generated theme.                                                           |
| `tmux/`         | tmux configuration.                                                                             |
| `vscode/user/`  | Editor settings, keybindings, and extensions for VS Code or VSCodium.                           |
| `zsh/`          | `.zshenv`, `.zprofile`, and `.zshrc`. The installer links these into the user's home directory. |

Themes in these folders are outputs. Edit the shared theme tokens and generator
when a theme needs to change; do not make a one-off edit to only one generated
theme file.

## Packages

`packages/` contains code that installs, generates, or extends the dotfiles.
Each package has a separate responsibility.

### `packages/installer/`

The machine installer is the only supported installation entry point. Its
important folders are:

```text
packages/installer/
├── install.sh       Entry point for full, phase, and single-strategy installs
├── setup/            OS-aware setup strategies, grouped by install phase
├── config/           Configuration owned by the installer
├── lib/              Installer-only Bash helpers
├── packages/         Package retirement data and schema
└── tests/            Tests that mirror install.sh, setup/, and lib/
```

Run the installer from a clean machine or disposable test VM. Do not run files
under `packages/installer/setup/` directly.

See [`packages/installer/README.md`](packages/installer/README.md) for the
install phases, supported systems, link behavior, and platform details. See
[`packages/installer/TESTING.md`](packages/installer/TESTING.md) for VM testing.

### `packages/lib/`

Shared libraries are independent of the installer.

- `packages/lib/bash/` contains reusable Bash libraries and cross-platform
  command-line tools. The `bin/` folder is for standalone tools.
- `packages/lib/ts/` is reserved for shared TypeScript. It is empty except for
  `.gitkeep` until shared code is added.

Installer-only helpers stay in `packages/installer/lib/`. This keeps the shared
library usable by other packages.

### `packages/mac/`

macOS-only tools live here. This includes small window, Dock, Finder, Ghostty,
and browser helpers, plus the canonical `mactop` source.

`packages/mac/mactop/` is an independent Go application. It monitors Apple
Silicon system resources and provides terminal, menu bar, overlay, and headless
interfaces. The installer builds this source for the machine. See its
[README](packages/mac/mactop/README.md) for build, configuration, and fan
control details.

### `packages/raycast/`

This folder contains Raycast extensions. Each direct child with a
`package.json` is one extension, for example:

- `better-screen-sharing/` opens and focuses Apple Screen Sharing connections.
- `better-time/` views and copies Unix millisecond timestamps.

[`packages/raycast/run.sh`](packages/raycast/run.sh) runs install, development,
build, test, typecheck, and format checks across all extensions.

### `packages/theming/`

This package owns the shared theme pipeline:

```text
packages/theming/create/tokens.css
        │
        ▼
packages/theming/create/controller.ts
        │
        ├── packages/theming/output/ghostty/
        ├── packages/theming/output/nvim/
        ├── packages/theming/output/oh-my-zsh/
        ├── packages/theming/output/superfile/
        └── packages/theming/output/vscode/
```

The theme install phase copies or links the generated output to the
application configuration folders and builds the VS Code theme package in
`packages/theming/vsce-package/`. The detailed generator diagram is in
[`packages/theming/create/README.md`](packages/theming/create/README.md).

### `packages/vscode-ext/`

This is the source for the private `better-vscode` extension. The
`errors` feature turns editor diagnostics into prompts that can be
copied for an LLM. The `terminal` feature focuses one pinned terminal
in the first editor group. Source and feature tests are under `src/features/`.
Browser test tools are under `tests/browser/`. Extension documentation is in
`packages/vscode-ext/README.md`.

### `packages/agent-usage/`

This TypeScript CLI reads the usage limits already stored by supported coding
agent CLIs and prints the remaining subscription usage. Its source is split
into `src/cli/`, `src/domain/`, and `src/providers/`; tests are in `tests/`.
The package does not store provider credentials.

## Dependency boundaries

The package layout is intentional:

```text
packages/lib/bash ─┐
packages/lib/ts   ─┼──> packages/mac
                  ├──> packages/raycast
                  ├──> packages/theming
                  └──> packages/vscode-ext

packages/installer ───> any lower-level package when it installs/configures it
```

Nothing depends on `packages/installer`. Reusable Bash code belongs in
`packages/lib/bash`; OS validation and package-install logic belong in the
installer. Mac-only tools belong in `packages/mac`.

## Installation

Clone this repository to the required path, then use the root commands or the
installer entry point:

```bash
git clone <repository-url> ~/.dotfiles
cd ~/.dotfiles
npm ci

npm run install:machine       # Full machine setup
npm run install:apps          # Applications phase
npm run install:development  # Development tools and settings
npm run install:theme         # Generate and install application themes
npm run install:agents        # Link agent instructions, settings, and skills
```

The machine setup commands above are thin wrappers around
`packages/installer/install.sh`. Use that script for other phases or when a
flag is not exposed by the root package scripts.

Run `npm run install:vscode-ext` from the repository root to build and install
better-vscode in VSCodium. Then run **Developer: Reload Window** in VSCodium.

The installer supports macOS and Debian 13 (trixie). Linux requires an Xfce,
LightDM, and X11 installation prepared before the dotfiles installer runs.
The installer asks for a machine name and color during a full install and
writes the result to the local, ignored `machine.json` file.

## Development commands

Run commands from the repository root unless a package README says otherwise.

```bash
npm run lint              # Check JavaScript and TypeScript
npm run format:check      # Check formatting
npm run typecheck         # Check referenced TypeScript projects
npm run install:test      # Check installer structure and shared libraries
npm run verify:machine    # Check links after a machine install
npm run test:mactop       # Test the Go mactop application
npm run test:agent-usage  # Test the agent-usage CLI
npm run raycast check     # Test all Raycast extensions
```

Installer changes need the checks in
[`packages/installer/TESTING.md`](packages/installer/TESTING.md). Full machine
tests run in disposable UTM clones, not on the main workstation.

## Working rules

- Keep the repository at `~/.dotfiles` when testing installation.
- Change shared theme inputs in `packages/theming/create/`, then regenerate
  outputs through the theme install flow.
- Add reusable cross-platform Bash code to `packages/lib/bash/`.
- Keep installer-specific code in `packages/installer/`.
- Keep tests beside the package or feature that they cover.
- Read [`AGENTS.md`](AGENTS.md) before changing repository structure.

## Documentation index

- [`AGENTS.md`](AGENTS.md) — repository rules and package boundaries
- [`packages/installer/README.md`](packages/installer/README.md) — installer
- [`packages/installer/TESTING.md`](packages/installer/TESTING.md) — VM and
  no-VM tests
- [`packages/mac/mactop/README.md`](packages/mac/mactop/README.md) — mactop
- [`packages/agent-usage/README.md`](packages/agent-usage/README.md) — usage
  CLI
- [`packages/vscode-ext/README.md`](packages/vscode-ext/README.md) — editor
  extension
- [`packages/theming/create/README.md`](packages/theming/create/README.md) —
  theme generation
