import * as vscode from "vscode";

import { BETTER_ERRORS_COMMANDS } from "../commands";
import { BETTER_ERRORS_CONFIG } from "../../../shared/consts/betterErrors";
import { copyActiveError } from "./copyActiveError";
import { isBetterErrorsEnabled } from "../settings";

export function registerCopyErrorCommands(): vscode.Disposable[] {
	return [registerCopyErrorCommand(), registerToggleEnabledCommand()];
}

function registerCopyErrorCommand(): vscode.Disposable {
	return vscode.commands.registerCommand(
		BETTER_ERRORS_COMMANDS.copyError,
		async (_uri?: vscode.Uri, targetRange?: vscode.Range) => {
			if (!isBetterErrorsEnabled()) {
				void vscode.window.showInformationMessage("better-errors is disabled.");
				return;
			}

			const editor = vscode.window.activeTextEditor;

			if (!editor) {
				void vscode.window.showWarningMessage(
					"Open a file before copying an error.",
				);
				return;
			}

			const didCopy = await copyActiveError(editor, targetRange);

			if (!didCopy) {
				void vscode.window.showWarningMessage(
					"No diagnostic found at the current cursor or selection.",
				);
				return;
			}

			void vscode.window.showInformationMessage("Copied error prompt.");
		},
	);
}

function registerToggleEnabledCommand(): vscode.Disposable {
	return vscode.commands.registerCommand(
		BETTER_ERRORS_COMMANDS.toggleEnabled,
		async () => {
			const config = vscode.workspace.getConfiguration(
				BETTER_ERRORS_CONFIG.root,
			);
			const nextEnabled = !isBetterErrorsEnabled();

			await config.update(
				BETTER_ERRORS_CONFIG.enabled,
				nextEnabled,
				vscode.ConfigurationTarget.Global,
			);

			void vscode.window.showInformationMessage(
				`better-errors ${nextEnabled ? "enabled" : "disabled"}.`,
			);
		},
	);
}
