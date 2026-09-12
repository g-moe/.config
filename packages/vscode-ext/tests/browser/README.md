# Browser tests

Use an extracted VSCodium Web Host release that matches the installed editor.
From `packages/vscode-ext`:

```bash
BETTER_VSCODE_TEST_SERVER_DIR=/path/to/server npm run test:integration
```

Open the printed URL in the in-app browser, trust the temporary folder, and run
**better-vscode Tests: Run Terminal Tests**. Use a fresh server for each run;
stop it with Ctrl+C when finished. No desktop editor opens.

The suite has 189 cases for terminal placement, focus, lifecycle, and speed.
These include direct commands from a maximized code editor, Git and Explorer
focus, locked editor groups, and maximized editor, panel, and secondary sidebar
views. The temporary workspace has its own Git repository.
The browser adapter in `check.js` exports `checkCheckpoint(browser, keyboard,
id, phase, proofPath)`. Call it with `before` and `after` for cases 1–189. Pass the
browser handle with `.playwright`, the keyboard handle with `.pressKey()` and
`.typeText()`, and the printed report path plus `.input`.

F17/F18 invoke the public commands directly from workbench controls; other cases
use the Command Palette. F19 continues the test. The adapter checks the UI, then
types proof through the current focus. Do not focus the terminal before typing.
Test commands, bindings, and files are excluded from the VSIX.

A run passes only when all cases pass. Existing-shell calls have a 500 ms limit;
creation and queued batches have a 2,000 ms limit. Browser timing includes tool
overhead. Twenty warm samples per Search/Explorer and command combination must
keep p95 within 20 ms of `baseline.json`. These four values came from the macOS
VSCodium 1.126.04524 baseline. Use `BETTER_VSCODE_TEST_BASELINE` for a measured
baseline on another host; do not raise limits to hide a slowdown.

Run reports stay in the temporary test folder.
