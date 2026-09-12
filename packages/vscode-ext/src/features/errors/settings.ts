import * as vscode from "vscode";

import { BETTER_ERRORS_CONFIG } from "../../shared/consts/betterErrors";

export function isBetterErrorsEnabled(): boolean {
	return vscode.workspace
		.getConfiguration(BETTER_ERRORS_CONFIG.root)
		.get(BETTER_ERRORS_CONFIG.enabled, true);
}
