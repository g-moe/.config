import test from "node:test";
import assert from "node:assert/strict";

import { buildCopyErrorPrompt } from "../../prompting/buildCopyErrorPrompt";
import type { BetterErrorDiagnostic } from "../../../../shared/contracts/betterErrors";

test("buildCopyErrorPrompt includes trimmed high-signal sections", () => {
	const diagnostic: BetterErrorDiagnostic = {
		filePath: "src/app.ts",
		documentLanguageId: "typescript",
		range: {
			start: { line: 4, character: 2 },
			end: { line: 4, character: 18 },
		},
		selection: {
			start: { line: 4, character: 0 },
			end: { line: 6, character: 1 },
		},
		severity: "error",
		message: "Type 'string' is not assignable to type 'number'.",
		rawMessage:
			"Type 'string' is not assignable to type 'number'.\n  The expected type comes from property 'count'.",
		source: "ts",
		code: "2322",
		relatedInformation: [
			{
				filePath: "src/types.ts",
				range: {
					start: { line: 0, character: 13 },
					end: { line: 0, character: 18 },
				},
				message: "'count' is declared here.",
			},
		],
		contextText: "const payload = {\n  count: value,\n};\n",
		activeScope: {
			filePath: "src/app.ts",
			range: {
				start: { line: 2, character: 0 },
				end: { line: 6, character: 1 },
			},
			languageId: "typescript",
			text: "const payload = {\n  count: value,\n};\n",
		},
		definition: {
			filePath: "src/value.ts",
			range: {
				start: { line: 0, character: 13 },
				end: { line: 0, character: 18 },
			},
			languageId: "typescript",
			text: "export const value = 'x';\n",
		},
		typeDefinition: {
			filePath: "src/types.ts",
			range: {
				start: { line: 0, character: 0 },
				end: { line: 0, character: 22 },
			},
			languageId: "typescript",
			text: "export type Count = number;\n",
		},
		references: [
			{
				filePath: "src/a.ts",
				range: {
					start: { line: 9, character: 2 },
					end: { line: 9, character: 7 },
				},
				snippet: "foo(value)",
			},
		],
		callHierarchy: {
			incoming: [
				{
					name: "buildPayload",
					filePath: "src/a.ts",
					range: {
						start: { line: 9, character: 0 },
						end: { line: 9, character: 12 },
					},
				},
			],
			outgoing: [
				{
					name: "normalizeValue",
					filePath: "src/value.ts",
					range: {
						start: { line: 2, character: 0 },
						end: { line: 2, character: 14 },
					},
				},
			],
		},
	};

	const prompt = buildCopyErrorPrompt({ diagnostic });

	assert.match(prompt, /## Raw Diagnostic/);
	assert.match(prompt, /- File: src\/app\.ts/);
	assert.match(
		prompt,
		/## Active Scope\n- File: src\/app\.ts\n- Range: 3:1-7:2\n```typescript/,
	);
	assert.match(prompt, /## Definition Snippet\n- File: src\/value\.ts/);
	assert.match(prompt, /## Type Definition Snippet\n- File: src\/types\.ts/);
	assert.match(prompt, /## Related Diagnostics/);
	assert.match(prompt, /- src\/types\.ts:1:14-1:19 'count' is declared here\./);
	assert.match(prompt, /## References/);
	assert.match(prompt, /- src\/a\.ts:10:3-10:8 foo\(value\)/);
	assert.match(prompt, /## Call Hierarchy/);
	assert.match(prompt, /- Called by: buildPayload in src\/a\.ts:10:1-10:13/);
	assert.match(
		prompt,
		/- Calls into: normalizeValue in src\/value\.ts:3:1-3:15/,
	);
	assert.doesNotMatch(prompt, /## Facts/);
	assert.doesNotMatch(prompt, /## Primary Symbol/);
});

test("buildCopyErrorPrompt includes placeholders when optional evidence is missing", () => {
	const diagnostic: BetterErrorDiagnostic = {
		filePath: "main.py",
		documentLanguageId: "python",
		range: {
			start: { line: 0, character: 0 },
			end: { line: 0, character: 5 },
		},
		selection: {
			start: { line: 0, character: 0 },
			end: { line: 0, character: 0 },
		},
		severity: "warning",
		message: "Unused variable 'x'",
		rawMessage: "Unused variable 'x'",
		relatedInformation: [],
		contextText: "",
		references: [],
	};

	const prompt = buildCopyErrorPrompt({ diagnostic });

	assert.match(prompt, /## Active Scope\n- <no enclosing scope found>/);
	assert.match(prompt, /## Definition Snippet\n- <no definition found>/);
	assert.match(
		prompt,
		/## Type Definition Snippet\n- <no type definition found>/,
	);
	assert.match(prompt, /## Related Diagnostics\n- <no related diagnostics>/);
	assert.match(prompt, /## References\n- <no references found>/);
	assert.match(prompt, /## Call Hierarchy\n- <no call hierarchy available>/);
});
