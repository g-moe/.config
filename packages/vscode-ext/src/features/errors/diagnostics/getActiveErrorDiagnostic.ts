import * as vscode from "vscode";

import type {
	BetterErrorCallHierarchy,
	BetterErrorCallHierarchyItem,
	BetterErrorCodeSnippet,
	BetterErrorDiagnostic,
	BetterErrorReference,
} from "../../../shared/contracts/betterErrors";
import { BETTER_ERRORS_CONFIG } from "../../../shared/consts/betterErrors";
import {
	formatDiagnosticSeverity,
	toBetterErrorRange,
} from "../../../shared/diagnostics";
import { selectDiagnostic } from "./selectDiagnostic";

const MAX_REFERENCES = 5;
const DEFINITION_CONTEXT_LINES = 20;
const CALL_HIERARCHY_LIMIT = 5;
const MAX_SCOPE_LINES = 120;

export async function getActiveErrorDiagnostic(
	editor: vscode.TextEditor,
	targetRange?: vscode.Range,
): Promise<BetterErrorDiagnostic | undefined> {
	const diagnostics = vscode.languages.getDiagnostics(editor.document.uri);
	const selection = editor.selection;
	const effectiveRange = targetRange ?? selection;
	const effectiveActivePosition = targetRange?.start ?? selection.active;
	const diagnostic = selectDiagnostic(
		diagnostics.map((item) => ({
			diagnostic: item,
			range: toBetterErrorRange(item.range),
			severity: formatDiagnosticSeverity(item.severity),
		})),
		toBetterErrorRange(effectiveRange),
		effectiveActivePosition,
	);

	if (!diagnostic) {
		return undefined;
	}

	const filePath = getFilePath(editor.document.uri);
	const diagnosticRange = toBetterErrorRange(diagnostic.range);
	const selectionRange = toBetterErrorRange(selection);
	const symbolPosition = effectiveActivePosition;
	const symbolRange =
		editor.document.getWordRangeAtPosition(symbolPosition) ?? diagnostic.range;
	const [activeScope, definition, typeDefinition, references, callHierarchy] =
		await Promise.all([
			getActiveScopeSnippet(editor.document, diagnostic.range),
			getDefinitionSnippet(editor.document.uri, symbolPosition),
			getTypeDefinitionSnippet(editor.document.uri, symbolPosition),
			getReferences(
				editor.document.uri,
				symbolPosition,
				editor.document.uri,
				symbolRange,
			),
			getCallHierarchy(editor.document.uri, symbolPosition),
		]);

	return {
		filePath,
		documentLanguageId: editor.document.languageId,
		range: diagnosticRange,
		selection: selectionRange,
		severity: formatDiagnosticSeverity(diagnostic.severity),
		message: diagnostic.message,
		rawMessage: diagnostic.message,
		source: diagnostic.source,
		code: normalizeDiagnosticCode(diagnostic.code),
		relatedInformation: (diagnostic.relatedInformation ?? []).map((item) => ({
			filePath: getFilePath(item.location.uri),
			range: toBetterErrorRange(item.location.range),
			message: item.message,
		})),
		contextText: editor.document.getText(
			expandRangeByLines(
				editor.document,
				diagnostic.range,
				getContextLineCount(),
			),
		),
		activeScope,
		definition,
		typeDefinition,
		references,
		callHierarchy,
	};
}

function expandRangeByLines(
	document: vscode.TextDocument,
	range: vscode.Range,
	paddingLineCount: number,
): vscode.Range {
	const startLine = Math.max(0, range.start.line - paddingLineCount);
	const endLine = Math.min(
		document.lineCount - 1,
		range.end.line + paddingLineCount,
	);

	return new vscode.Range(
		new vscode.Position(startLine, 0),
		document.lineAt(endLine).range.end,
	);
}

function getContextLineCount(): number {
	return vscode.workspace
		.getConfiguration(BETTER_ERRORS_CONFIG.root)
		.get<number>(BETTER_ERRORS_CONFIG.contextLineCount, 12);
}

function getFilePath(uri: vscode.Uri): string {
	const includeWorkspaceRelativePath = vscode.workspace
		.getConfiguration(BETTER_ERRORS_CONFIG.root)
		.get<boolean>(BETTER_ERRORS_CONFIG.includeWorkspaceRelativePath, true);

	return includeWorkspaceRelativePath
		? vscode.workspace.asRelativePath(uri, false)
		: uri.fsPath;
}

async function getActiveScopeSnippet(
	document: vscode.TextDocument,
	diagnosticRange: vscode.Range,
): Promise<BetterErrorCodeSnippet | undefined> {
	const symbols = await vscode.commands.executeCommand<
		readonly vscode.DocumentSymbol[] | readonly vscode.SymbolInformation[]
	>("vscode.executeDocumentSymbolProvider", document.uri);
	const scopeRange = getNarrowestContainingSymbolRange(
		document.uri,
		symbols ?? [],
		diagnosticRange,
	);
	const snippetRange =
		scopeRange && getLineSpan(scopeRange) <= MAX_SCOPE_LINES
			? scopeRange
			: expandRangeByLines(document, diagnosticRange, getContextLineCount());

	return {
		filePath: getFilePath(document.uri),
		range: toBetterErrorRange(snippetRange),
		languageId: document.languageId,
		text: document.getText(snippetRange),
	};
}

async function getDefinitionSnippet(
	uri: vscode.Uri,
	position: vscode.Position,
): Promise<BetterErrorCodeSnippet | undefined> {
	const locations = await vscode.commands.executeCommand<
		readonly vscode.Location[] | readonly vscode.LocationLink[]
	>("vscode.executeDefinitionProvider", uri, position);

	return toCodeSnippet(locations?.[0]);
}

async function getTypeDefinitionSnippet(
	uri: vscode.Uri,
	position: vscode.Position,
): Promise<BetterErrorCodeSnippet | undefined> {
	const locations = await vscode.commands.executeCommand<
		readonly vscode.Location[] | readonly vscode.LocationLink[]
	>("vscode.executeTypeDefinitionProvider", uri, position);

	return toCodeSnippet(locations?.[0]);
}

async function getReferences(
	uri: vscode.Uri,
	position: vscode.Position,
	currentUri: vscode.Uri,
	currentRange: vscode.Range,
): Promise<readonly BetterErrorReference[]> {
	const locations = await vscode.commands.executeCommand<
		readonly vscode.Location[]
	>("vscode.executeReferenceProvider", uri, position);

	if (!locations) {
		return [];
	}

	const filteredLocations = locations.filter(
		(item) =>
			!(
				item.uri.toString() === currentUri.toString() &&
				item.range.isEqual(currentRange)
			),
	);
	const uniqueLocations = dedupeLocations(filteredLocations).slice(
		0,
		MAX_REFERENCES,
	);

	return Promise.all(uniqueLocations.map(toReference));
}

async function getCallHierarchy(
	uri: vscode.Uri,
	position: vscode.Position,
): Promise<BetterErrorCallHierarchy | undefined> {
	const items = await vscode.commands.executeCommand<
		vscode.CallHierarchyItem[]
	>("vscode.prepareCallHierarchy", uri, position);
	const item = items?.[0];

	if (!item) {
		return undefined;
	}

	const [incomingCalls, outgoingCalls] = await Promise.all([
		vscode.commands.executeCommand<vscode.CallHierarchyIncomingCall[]>(
			"vscode.provideIncomingCalls",
			item,
		),
		vscode.commands.executeCommand<vscode.CallHierarchyOutgoingCall[]>(
			"vscode.provideOutgoingCalls",
			item,
		),
	]);

	const incoming = (incomingCalls ?? [])
		.slice(0, CALL_HIERARCHY_LIMIT)
		.map((call) => toCallHierarchyItem(call.from));
	const outgoing = (outgoingCalls ?? [])
		.slice(0, CALL_HIERARCHY_LIMIT)
		.map((call) => toCallHierarchyItem(call.to));

	if (incoming.length === 0 && outgoing.length === 0) {
		return undefined;
	}

	return { incoming, outgoing };
}

function dedupeLocations(
	locations: readonly vscode.Location[],
): readonly vscode.Location[] {
	const seen = new Set<string>();

	return locations.filter((item) => {
		const key = `${item.uri.toString()}:${item.range.start.line}:${item.range.start.character}:${item.range.end.line}:${item.range.end.character}`;

		if (seen.has(key)) {
			return false;
		}

		seen.add(key);
		return true;
	});
}

async function toReference(
	location: vscode.Location,
): Promise<BetterErrorReference> {
	const document = await vscode.workspace.openTextDocument(location.uri);
	const lineText = document.lineAt(location.range.start.line).text.trim();

	return {
		filePath: getFilePath(location.uri),
		range: toBetterErrorRange(location.range),
		snippet: lineText,
	};
}

async function toCodeSnippet(
	location: vscode.Location | vscode.LocationLink | undefined,
): Promise<BetterErrorCodeSnippet | undefined> {
	if (!location) {
		return undefined;
	}

	const targetUri = "targetUri" in location ? location.targetUri : location.uri;
	const targetRange =
		"targetRange" in location ? location.targetRange : location.range;
	const document = await vscode.workspace.openTextDocument(targetUri);
	const snippetRange = expandRangeByLines(
		document,
		targetRange,
		DEFINITION_CONTEXT_LINES,
	);

	return {
		filePath: getFilePath(targetUri),
		range: toBetterErrorRange(targetRange),
		languageId: document.languageId,
		text: document.getText(snippetRange),
	};
}

function toCallHierarchyItem(
	item: vscode.CallHierarchyItem,
): BetterErrorCallHierarchyItem {
	return {
		name: item.name,
		filePath: getFilePath(item.uri),
		range: toBetterErrorRange(item.range),
	};
}

function getNarrowestContainingSymbolRange(
	uri: vscode.Uri,
	symbols:
		| readonly vscode.DocumentSymbol[]
		| readonly vscode.SymbolInformation[],
	targetRange: vscode.Range,
): vscode.Range | undefined {
	if (symbols.length === 0) {
		return undefined;
	}

	const firstSymbol = symbols[0];
	const candidateRanges = isDocumentSymbol(firstSymbol)
		? flattenDocumentSymbols(symbols as readonly vscode.DocumentSymbol[]).map(
				(item) => item.range,
			)
		: (symbols as readonly vscode.SymbolInformation[])
				.filter((item) => item.location.uri.toString() === uri.toString())
				.map((item) => item.location.range);

	return candidateRanges
		.filter((range) => rangeContainsRange(range, targetRange))
		.sort((left, right) => getRangeArea(left) - getRangeArea(right))[0];
}

function flattenDocumentSymbols(
	symbols: readonly vscode.DocumentSymbol[],
): readonly vscode.DocumentSymbol[] {
	return symbols.flatMap((symbol) => [
		symbol,
		...flattenDocumentSymbols(symbol.children),
	]);
}

function isDocumentSymbol(
	symbol: vscode.DocumentSymbol | vscode.SymbolInformation,
): symbol is vscode.DocumentSymbol {
	return "children" in symbol;
}

function rangeContainsRange(
	container: vscode.Range,
	target: vscode.Range,
): boolean {
	return container.contains(target.start) && container.contains(target.end);
}

function getRangeArea(range: vscode.Range): number {
	return (
		getLineSpan(range) * 10000 + (range.end.character - range.start.character)
	);
}

function getLineSpan(range: vscode.Range): number {
	return range.end.line - range.start.line;
}

function normalizeDiagnosticCode(
	code: vscode.Diagnostic["code"],
): string | undefined {
	if (typeof code === "string") {
		return code;
	}

	if (typeof code === "number") {
		return String(code);
	}

	if (code && typeof code === "object" && "value" in code) {
		return String(code.value);
	}

	return undefined;
}
