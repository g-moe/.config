import test from "node:test";
import assert from "node:assert/strict";

import { selectCodeLensDiagnostics } from "../../diagnostics/selectCodeLensDiagnostics";
import type {
	BetterErrorRange,
	BetterErrorSeverity,
} from "../../../../shared/contracts/betterErrors";
import type { SelectableDiagnostic } from "../../diagnostics/selectDiagnostic";

test("selectCodeLensDiagnostics returns the strongest diagnostic per line", () => {
	const diagnostics = [
		createDiagnostic("line-2-warning", range(1, 0, 1, 10), "warning"),
		createDiagnostic("line-2-error", range(1, 2, 1, 4), "error"),
		createDiagnostic("line-4-info", range(3, 1, 3, 8), "information"),
	];

	assert.deepEqual(selectCodeLensDiagnostics(diagnostics), [
		"line-2-error",
		"line-4-info",
	]);
});

test("selectCodeLensDiagnostics preserves line order", () => {
	const diagnostics = [
		createDiagnostic("line-5", range(4, 0, 4, 1), "warning"),
		createDiagnostic("line-1", range(0, 0, 0, 1), "error"),
	];

	assert.deepEqual(selectCodeLensDiagnostics(diagnostics), [
		"line-1",
		"line-5",
	]);
});

function createDiagnostic<TDiagnostic>(
	diagnostic: TDiagnostic,
	range: BetterErrorRange,
	severity: BetterErrorSeverity,
): SelectableDiagnostic<TDiagnostic> {
	return {
		diagnostic,
		range,
		severity,
	};
}

function range(
	startLine: number,
	startCharacter: number,
	endLine: number,
	endCharacter: number,
): BetterErrorRange {
	return {
		start: { line: startLine, character: startCharacter },
		end: { line: endLine, character: endCharacter },
	};
}
