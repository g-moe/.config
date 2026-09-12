import * as vscode from "vscode";

// Keep the workbench operations in order: each one acts on the active editor.
export async function focusTerminalEditor(
	terminal: vscode.Terminal,
	maximize: boolean,
	signal: AbortSignal,
) {
	signal.throwIfAborted();

	const editorGroup = vscode.window.tabGroups.all.find((group) =>
		group.tabs.some(
			(tab) =>
				tab.input instanceof vscode.TabInputTerminal &&
				tab.label === terminal.name,
		),
	);

	// Terminal.show() can reveal a tab without selecting its editor group.
	// Select that group before using commands that act on the active tab.
	if (editorGroup && !editorGroup.isActive) {
		await vscode.commands.executeCommand(
			"workbench.action.focusFirstEditorGroup",
		);
		await waitUntil(
			() => vscode.window.tabGroups.activeTabGroup.viewColumn === 1,
		);

		for (let column = 2; column <= editorGroup.viewColumn; column++) {
			signal.throwIfAborted();
			await vscode.commands.executeCommand("workbench.action.focusNextGroup");
			await waitUntil(
				() => vscode.window.tabGroups.activeTabGroup.viewColumn === column,
			);
		}
	}

	// show() returns void. Wait for the public API state before the next command.
	terminal.show();
	await waitUntil(() => vscode.window.activeTerminal === terminal);

	// A terminal in the panel must move into the editor before tab operations.
	if (!editorGroup) {
		await vscode.commands.executeCommand("workbench.action.terminal.focus");
		assertActiveTerminal(terminal, signal, false);
		await vscode.commands.executeCommand(
			"workbench.action.terminal.moveToEditor",
		);
	}

	await waitUntil(() => activeTerminalTab(terminal) !== undefined);
	terminal.show();
	await waitUntil(() => vscode.window.activeTerminal === terminal);

	// Clear any multiple-tab selection so only the terminal moves to group 1.
	const tab = activeTerminalTab(terminal)!;

	await vscode.commands.executeCommand(
		"workbench.action.openEditorAtIndex",
		tab.group.tabs.indexOf(tab),
	);
	assertActiveTerminal(terminal, signal);
	await vscode.commands.executeCommand("moveActiveEditor", {
		to: "first",
		by: "group",
	});
	await waitUntil(
		() =>
			activeTerminalTab(terminal)?.group.viewColumn === vscode.ViewColumn.One,
	);

	// Moving a tab can change terminal focus. Restore it before pinning.
	terminal.show();
	await waitUntil(() => vscode.window.activeTerminal === terminal);
	assertActiveTerminal(terminal, signal);

	// VS Code calls a sticky tab "pinned". Pin first, then place it before other pins.
	await vscode.commands.executeCommand("workbench.action.pinEditor");
	assertActiveTerminal(terminal, signal);
	await vscode.commands.executeCommand("moveActiveEditor", {
		to: "first",
		by: "tab",
	});
	await waitUntil(() => {
		const tab = activeTerminalTab(terminal);

		return (
			vscode.window.activeTerminal === terminal &&
			tab?.group.viewColumn === vscode.ViewColumn.One &&
			tab?.isPinned === true &&
			tab.group.tabs[0] === tab
		);
	});

	// This is a one-way maximize command; repeated calls must not toggle it off.
	if (maximize) {
		assertActiveTerminal(terminal, signal);
		await vscode.commands.executeCommand(
			"workbench.action.maximizeEditorHideSidebar",
		);
	}

	assertActiveTerminal(terminal, signal);

	// Tab events arrive after the commands complete. Bound every state wait and
	// stop immediately if the terminal closes or the extension is disposed.
	async function waitUntil(check: () => boolean) {
		const deadline = Date.now() + 5000;

		while (!check()) {
			signal.throwIfAborted();

			if (
				terminal.exitStatus !== undefined ||
				!vscode.window.terminals.includes(terminal)
			) {
				throw new Error("The terminal closed. Run the command again.");
			}

			if (Date.now() >= deadline) {
				throw new Error(
					"VS Code did not finish opening or moving the terminal.",
				);
			}

			await new Promise((resolve) => setTimeout(resolve, 20));
		}
	}
}

function activeTerminalTab(terminal: vscode.Terminal) {
	const tab = vscode.window.tabGroups.activeTabGroup.activeTab;

	return tab?.input instanceof vscode.TabInputTerminal &&
		tab.label === terminal.name
		? tab
		: undefined;
}

function assertActiveTerminal(
	terminal: vscode.Terminal,
	signal: AbortSignal,
	editorRequired = true,
) {
	signal.throwIfAborted();

	if (
		vscode.window.activeTerminal !== terminal ||
		terminal.exitStatus !== undefined ||
		(editorRequired && !activeTerminalTab(terminal))
	) {
		throw new Error(
			"The terminal changed or closed. Run Focus Terminal again.",
		);
	}
}
