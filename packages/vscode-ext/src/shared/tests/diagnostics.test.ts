import assert from "node:assert/strict";
import test from "node:test";

import { formatDiagnosticSeverity, toBetterErrorRange } from "../diagnostics";

test("formatDiagnosticSeverity maps known VS Code severity values", () => {
	assert.deepEqual([0, 1, 2, 3].map(formatDiagnosticSeverity), [
		"error",
		"warning",
		"information",
		"hint",
	]);
});

test("formatDiagnosticSeverity marks unknown severity values", () => {
	assert.equal(formatDiagnosticSeverity(99), "unknown");
});

test("toBetterErrorRange copies position values", () => {
	const source = {
		start: { line: 2, character: 4 },
		end: { line: 5, character: 8 },
	};

	const result = toBetterErrorRange(source);

	assert.deepEqual(result, source);
	assert.notEqual(result, source);
	assert.notEqual(result.start, source.start);
	assert.notEqual(result.end, source.end);
});
