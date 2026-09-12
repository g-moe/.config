import type {
	BetterErrorCodeSnippet,
	BetterErrorPromptInput,
	BetterErrorRange,
} from "../../../shared/contracts/betterErrors";
import { BETTER_ERRORS_PROMPT_DEFAULTS } from "../../../shared/consts/betterErrors";

export function buildCopyErrorPrompt({
	diagnostic,
}: BetterErrorPromptInput): string {
	return trimTrailingBlankLines([
		...buildInstructionSection(),
		...buildRawDiagnosticSection(diagnostic),
		...buildActiveScopeSection(diagnostic),
		...buildDefinitionSection(diagnostic),
		...buildTypeDefinitionSection(diagnostic),
		...buildRelatedInformationSection(diagnostic),
		...buildReferencesSection(diagnostic),
		...buildCallHierarchySection(diagnostic),
	]).join("\n");
}

function buildInstructionSection(): string[] {
	return [
		BETTER_ERRORS_PROMPT_DEFAULTS.instruction,
		"",
		"Tasks:",
		"1. Identify the most likely root cause.",
		"2. Explain it clearly and concretely for an engineer.",
		"3. Suggest the smallest correct fix.",
		"4. If there are multiple plausible causes, rank them briefly.",
		"5. If the evidence is still insufficient, say what to inspect next.",
		"",
		"Rules:",
		"- Ground the answer in the provided evidence.",
		"- Do not invent files, APIs, or types.",
		"- Prefer the active scope, definitions, references, and related diagnostics over generic guesses.",
		"- Keep the answer focused and technical.",
		"- Prefer annotated code blocks over prose paragraphs.",
		"- Use short comments around the relevant code to explain the problem and the fix.",
		"- If code alone would be too verbose, add a compact table or mermaid diagram alongside the code blocks.",
		"",
		"Return sections:",
		"- Root cause",
		"- Best fix",
		"- Relevant code",
		"- Why",
		"- Other plausible causes",
		"- Next evidence to inspect",
		"",
	];
}

function buildRawDiagnosticSection(
	diagnostic: BetterErrorPromptInput["diagnostic"],
): string[] {
	return [
		"## Raw Diagnostic",
		`- Message: ${diagnostic.rawMessage}`,
		`- Severity: ${diagnostic.severity}`,
		`- Source: ${withFallback(diagnostic.source, "<unknown>")}`,
		`- Code: ${withFallback(diagnostic.code, "<unknown>")}`,
		`- File: ${diagnostic.filePath}`,
		`- Range: ${formatRange(diagnostic.range)}`,
		"",
	];
}

function buildActiveScopeSection(
	diagnostic: BetterErrorPromptInput["diagnostic"],
): string[] {
	return buildSnippetSection({
		label: "## Active Scope",
		snippet: diagnostic.activeScope,
		fallback: BETTER_ERRORS_PROMPT_DEFAULTS.emptyActiveScopePlaceholder,
	});
}

function buildDefinitionSection(
	diagnostic: BetterErrorPromptInput["diagnostic"],
): string[] {
	return buildSnippetSection({
		label: "## Definition Snippet",
		snippet: diagnostic.definition,
		fallback: BETTER_ERRORS_PROMPT_DEFAULTS.emptyDefinitionPlaceholder,
	});
}

function buildTypeDefinitionSection(
	diagnostic: BetterErrorPromptInput["diagnostic"],
): string[] {
	return buildSnippetSection({
		label: "## Type Definition Snippet",
		snippet: diagnostic.typeDefinition,
		fallback: BETTER_ERRORS_PROMPT_DEFAULTS.emptyTypeDefinitionPlaceholder,
	});
}

function buildRelatedInformationSection(
	diagnostic: BetterErrorPromptInput["diagnostic"],
): string[] {
	return [
		"## Related Diagnostics",
		...(diagnostic.relatedInformation.length > 0
			? diagnostic.relatedInformation.map(
					(item) =>
						`- ${item.filePath}:${formatRange(item.range)} ${item.message}`,
				)
			: [
					`- ${BETTER_ERRORS_PROMPT_DEFAULTS.emptyRelatedDiagnosticsPlaceholder}`,
				]),
		"",
	];
}

function buildReferencesSection(
	diagnostic: BetterErrorPromptInput["diagnostic"],
): string[] {
	return [
		"## References",
		...(diagnostic.references.length > 0
			? diagnostic.references.map(
					(item) =>
						`- ${item.filePath}:${formatRange(item.range)} ${item.snippet}`,
				)
			: [`- ${BETTER_ERRORS_PROMPT_DEFAULTS.emptyReferencesPlaceholder}`]),
		"",
	];
}

function buildCallHierarchySection(
	diagnostic: BetterErrorPromptInput["diagnostic"],
): string[] {
	if (!diagnostic.callHierarchy) {
		return [
			"## Call Hierarchy",
			`- ${BETTER_ERRORS_PROMPT_DEFAULTS.emptyCallHierarchyPlaceholder}`,
			"",
		];
	}

	return [
		"## Call Hierarchy",
		...(diagnostic.callHierarchy.incoming.length > 0
			? diagnostic.callHierarchy.incoming.map(
					(item) =>
						`- Called by: ${item.name} in ${item.filePath}:${formatRange(item.range)}`,
				)
			: ["- Called by: <none>"]),
		...(diagnostic.callHierarchy.outgoing.length > 0
			? diagnostic.callHierarchy.outgoing.map(
					(item) =>
						`- Calls into: ${item.name} in ${item.filePath}:${formatRange(item.range)}`,
				)
			: ["- Calls into: <none>"]),
		"",
	];
}

function buildSnippetSection({
	label,
	snippet,
	fallback,
}: {
	label: string;
	snippet: BetterErrorCodeSnippet | undefined;
	fallback: string;
}): string[] {
	if (!snippet) {
		return [label, `- ${fallback}`, ""];
	}

	return [
		label,
		`- File: ${snippet.filePath}`,
		`- Range: ${formatRange(snippet.range)}`,
		`\`\`\`${snippet.languageId}`,
		snippet.text,
		"```",
		"",
	];
}

function withFallback(value: string | undefined, fallback: string): string {
	return value && value.length > 0 ? value : fallback;
}

function trimTrailingBlankLines(lines: string[]): string[] {
	const endIndex = [...lines].reverse().findIndex((line) => line.length > 0);

	return endIndex === -1 ? [] : lines.slice(0, lines.length - endIndex);
}

function formatRange(range: BetterErrorRange): string {
	return `${range.start.line + 1}:${range.start.character + 1}-${range.end.line + 1}:${range.end.character + 1}`;
}
