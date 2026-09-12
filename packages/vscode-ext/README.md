# better-vscode

Private VS Code extension for editor productivity tools.

Features:

- `terminal`: focus one pinned terminal editor tab.
- `errors`: copy the full editor diagnostic into a prompt for an LLM.

## Naming

Feature folders use plain names: `terminal`, `errors`, `search`.
Command IDs use `better-vscode.<feature>.<action>`; labels use `better-vscode: <feature> - <action>`.

## Terminal commands

Open the Command Palette and select:

- **better-vscode: terminal - focus** — create or reuse the extension's terminal,
  move it to group 1, pin it at tab position 1, and focus its input.
- **better-vscode: terminal - focus & maximize** — do the same, then maximize
  group 1 and hide the sidebars. Other groups stay open but are hidden.
  Repeated runs keep the group maximized.

Each run first selects the group that contains the terminal, then restores its
tab position and pin. If you close the terminal, the next run creates a new shell.
This also applies when the shell process has ended but VS Code still lists the
terminal as open. If you move it to the panel, the command returns it to the
editor. Other terminals are separate. Repeated runs reuse the same shell.

Keep the terminal name unique. If another terminal has the same name, the
command stops and asks you to rename one. VS Code's stable tab API does not
provide a terminal ID to distinguish tabs with the same title.

No hotkey is assigned. In Keyboard Shortcuts, search for `better-vscode.terminal.focus`
or `better-vscode.terminal.focusAndMaximize` to assign one.

Use **View: Toggle Maximize Editor Group** to show the other groups again.
The sidebars can be shown with their normal toggle commands.

The extension stores an owner ID in workspace state and in the terminal's
creation environment. It also stores the shell process ID and start time to find
the same running shell after a reload, because restored terminals can lose the
environment marker. A matching process ID with a different start time is not
accepted. Shell restoration depends on VS Code's persistent session settings.

Existing error command IDs and settings remain unchanged. Old terminal hotkeys
must use the new command IDs above. A terminal from the earlier prototype may
need to be closed once if its stored identity cannot be verified.

## Development

```bash
npm install
npm run compile
npm test
```

The terminal feature separates shell lifecycle (`service.ts`), editor operations
(`editor.ts`), public types (`contracts.ts`), and OS queries (`process.ts`).

Feature tests live under `src/features/<feature>/tests/`; shared tests live under
`src/shared/tests/`. The separate test extension, browser checks, and server script
live under `tests/browser/`. Production builds and the VSIX exclude both test locations.

Browser tests use an explicit VSCodium Web Host release and a fresh temporary
workspace. They check the public Command Palette commands, tab state, group size,
and actual keyboard input. Search and Explorer tests use direct command hotkeys.
Every case has a time limit, and repeated warm calls are compared with a saved baseline.
No desktop editor window opens.
See [browser test instructions](tests/browser/README.md).

## Local installs

From the repository root, run `npm run install:vscode-ext` to build and install
the extension in VSCodium. From this package directory, use:

```bash
npm run install:cursor
npm run install:codium
```

After an install or update, run **Developer: Reload Window** in each open editor
window. Replacing the VSIX does not replace extension code already loaded in memory.
