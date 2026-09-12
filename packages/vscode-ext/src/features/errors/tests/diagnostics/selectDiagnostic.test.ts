import test from "node:test";
import assert from "node:assert/strict";

import {
	selectDiagnostic,
	type SelectableDiagnostic,
} from "../../diagnostics/selectDiagnostic";
import type {
	BetterErrorPosition,
	BetterErrorRange,
	BetterErrorSeverity,
} from "../../../../shared/contracts/betterErrors";

test("selectDiagnostic prefers diagnostics containing the active position", () => {
	const diagnostics = [
		createDiagnostic("selection-only", range(2, 0, 2, 12), "warning"),
		createDiagnostic("active", range(3, 2, 3, 8), "warning"),
	];

	const selected = selectDiagnostic(
		diagnostics,
		range(2, 0, 3, 4),
		position(3, 3),
	);

	assert.equal(selected, "active");
});

test("selectDiagnostic prefers higher severity when multiple diagnostics contain the cursor", () => {
	const diagnostics = [
		createDiagnostic("warning", range(4, 0, 4, 20), "warning"),
		createDiagnostic("error", range(4, 5, 4, 10), "error"),
	];

	const selected = selectDiagnostic(
		diagnostics,
		range(4, 0, 4, 20),
		position(4, 6),
	);

	assert.equal(selected, "error");
});

test("selectDiagnostic falls back to intersecting diagnostics and prefers the smaller range on ties", () => {
	const diagnostics = [
		createDiagnostic("wide", range(7, 0, 9, 0), "information"),
		createDiagnostic("tight", range(8, 2, 8, 6), "information"),
	];

	const selected = selectDiagnostic(
		diagnostics,
		range(8, 0, 8, 10),
		position(12, 0),
	);

	assert.equal(selected, "tight");
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

function position(line: number, character: number): BetterErrorPosition {
	return { line, character };
}

function range(
	startLine: number,
	startCharacter: number,
	endLine: number,
	endCharacter: number,
): BetterErrorRange {
	return {
		start: position(startLine, startCharacter),
		end: position(endLine, endCharacter),
	};
}
