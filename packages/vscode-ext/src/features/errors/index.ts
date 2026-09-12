import * as vscode from "vscode";

import { registerCopyErrorCommands } from "./ui/registerCopyErrorCommand";
import { registerCopyErrorCodeLensProvider } from "./ui/registerCopyErrorCodeLensProvider";

export function registerBetterErrors(context: vscode.ExtensionContext) {
	context.subscriptions.push(
		...registerCopyErrorCommands(),
		registerCopyErrorCodeLensProvider(),
	);
}
