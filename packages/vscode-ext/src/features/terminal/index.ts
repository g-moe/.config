import * as vscode from "vscode";

import { TERMINAL_COMMANDS } from "./commands";
import { focusTerminalEditor } from "./editor";
import { TerminalService } from "./service";
import { readProcessStart, isProcessAlive } from "./process";
import type { TerminalState } from "./contracts";

export function registerBetterTerminal(context: vscode.ExtensionContext) {
	const stateKey = "better-vscode.terminal";
	const service = new TerminalService({
		terminals: () => vscode.window.terminals,
		create: (options) => vscode.window.createTerminal(options),
		onClose: vscode.window.onDidCloseTerminal,
		load: () => context.workspaceState.get<TerminalState>(stateKey),
		save: (state) => context.workspaceState.update(stateKey, state),
		processStart: readProcessStart,
		processAlive: isProcessAlive,
	});

	// Workbench commands share active-editor state. Serialize the whole operation,
	// not only shell creation, so rapid calls cannot move different active tabs.
	let pending = Promise.resolve();

	context.subscriptions.push(service);

	for (const [command, maximize] of [
		[TERMINAL_COMMANDS.focus, false],
		[TERMINAL_COMMANDS.focusAndMaximize, true],
	] as const) {
		context.subscriptions.push(
			vscode.commands.registerCommand(command, () => {
				const operation = pending.then(async () => {
					const terminal = await service.getTerminal();

					await focusTerminalEditor(terminal, maximize, service.signal);
				});

				// Return the failure to the caller, but allow the next command to run.
				pending = operation.catch(() => {});

				return operation;
			}),
		);
	}
}
