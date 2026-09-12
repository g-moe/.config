import * as vscode from "vscode";

import {
	BETTER_ERRORS_COMMANDS,
	BETTER_ERRORS_COMMAND_TITLES,
} from "../commands";
import { BETTER_ERRORS_CONFIG } from "../../../shared/consts/betterErrors";
import {
	formatDiagnosticSeverity,
	toBetterErrorRange,
} from "../../../shared/diagnostics";
import { selectCodeLensDiagnostics } from "../diagnostics/selectCodeLensDiagnostics";
import { isBetterErrorsEnabled } from "../settings";

export function registerCopyErrorCodeLensProvider(): vscode.Disposable {
	const onDidChangeCodeLenses = new vscode.EventEmitter<void>();

	const provider = vscode.languages.registerCodeLensProvider(
		[{ scheme: "file" }, { scheme: "untitled" }],
		{
			onDidChangeCodeLenses: onDidChangeCodeLenses.event,
			provideCodeLenses(document) {
				if (!isBetterErrorsEnabled()) {
					return [];
				}

				const diagnostics = selectCodeLensDiagnostics(
					vscode.languages.getDiagnostics(document.uri).map((diagnostic) => ({
						diagnostic,
						range: toBetterErrorRange(diagnostic.range),
						severity: formatDiagnosticSeverity(diagnostic.severity),
					})),
				);

				return diagnostics.map(
					(diagnostic) =>
						new vscode.CodeLens(diagnostic.range, {
							command: BETTER_ERRORS_COMMANDS.copyError,
							title: BETTER_ERRORS_COMMAND_TITLES.copyError,
							arguments: [document.uri, diagnostic.range],
						}),
				);
			},
		},
	);

	const diagnosticsSubscription = vscode.languages.onDidChangeDiagnostics(
		() => {
			onDidChangeCodeLenses.fire();
		},
	);

	const configurationSubscription = vscode.workspace.onDidChangeConfiguration(
		(event) => {
			if (
				event.affectsConfiguration(
					`${BETTER_ERRORS_CONFIG.root}.${BETTER_ERRORS_CONFIG.enabled}`,
				)
			) {
				onDidChangeCodeLenses.fire();
			}
		},
	);

	return vscode.Disposable.from(
		provider,
		diagnosticsSubscription,
		configurationSubscription,
		onDidChangeCodeLenses,
	);
}
