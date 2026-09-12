import * as vscode from "vscode";

import { registerBetterErrors } from "./features/errors";
import { registerBetterTerminal } from "./features/terminal";

export function activate(context: vscode.ExtensionContext) {
	// Each feature registers its commands and cleanup with the extension context.
	registerBetterErrors(context);
	registerBetterTerminal(context);
}
