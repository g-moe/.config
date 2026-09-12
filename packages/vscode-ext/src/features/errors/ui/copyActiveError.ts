import * as vscode from "vscode";

import { getActiveErrorDiagnostic } from "../diagnostics/getActiveErrorDiagnostic";
import { buildCopyErrorPrompt } from "../prompting/buildCopyErrorPrompt";

export async function copyActiveError(
	editor: vscode.TextEditor,
	targetRange?: vscode.Range,
): Promise<boolean> {
	const diagnostic = await getActiveErrorDiagnostic(editor, targetRange);

	if (!diagnostic) {
		return false;
	}

	const prompt = buildCopyErrorPrompt({ diagnostic });

	await vscode.env.clipboard.writeText(prompt);
	return true;
}
