import type {
	BetterErrorPosition,
	BetterErrorRange,
	BetterErrorSeverity,
} from "../../../shared/contracts/betterErrors";

export type SelectableDiagnostic<TDiagnostic> = {
	diagnostic: TDiagnostic;
	range: BetterErrorRange;
	severity: BetterErrorSeverity;
};

export function selectDiagnostic<TDiagnostic>(
	diagnostics: readonly SelectableDiagnostic<TDiagnostic>[],
	selection: BetterErrorRange,
	activePosition: BetterErrorPosition,
): TDiagnostic | undefined {
	const containing = diagnostics.filter((item) =>
		containsPosition(item.range, activePosition),
	);

	if (containing.length > 0) {
		return [...containing].sort(compareSelectableDiagnostics)[0]?.diagnostic;
	}

	const intersecting = diagnostics.filter((item) =>
		intersectsRange(item.range, selection),
	);

	return [...intersecting].sort(compareSelectableDiagnostics)[0]?.diagnostic;
}

export function compareSelectableDiagnostics<TDiagnostic>(
	left: SelectableDiagnostic<TDiagnostic>,
	right: SelectableDiagnostic<TDiagnostic>,
): number {
	const severityDelta =
		severityRank(left.severity) - severityRank(right.severity);

	if (severityDelta !== 0) {
		return severityDelta;
	}

	const spanDelta = rangeSpan(left.range) - rangeSpan(right.range);

	if (spanDelta !== 0) {
		return spanDelta;
	}

	const startDelta = comparePosition(left.range.start, right.range.start);

	if (startDelta !== 0) {
		return startDelta;
	}

	return comparePosition(left.range.end, right.range.end);
}

function containsPosition(
	range: BetterErrorRange,
	position: BetterErrorPosition,
): boolean {
	return (
		comparePosition(range.start, position) <= 0 &&
		comparePosition(position, range.end) <= 0
	);
}

function intersectsRange(
	left: BetterErrorRange,
	right: BetterErrorRange,
): boolean {
	return (
		comparePosition(left.start, right.end) <= 0 &&
		comparePosition(right.start, left.end) <= 0
	);
}

function comparePosition(
	left: BetterErrorPosition,
	right: BetterErrorPosition,
): number {
	if (left.line !== right.line) {
		return left.line - right.line;
	}

	return left.character - right.character;
}

function rangeSpan(range: BetterErrorRange): number {
	return (
		(range.end.line - range.start.line) * 10000 +
		(range.end.character - range.start.character)
	);
}

function severityRank(severity: BetterErrorSeverity): number {
	switch (severity) {
		case "error":
			return 0;
		case "warning":
			return 1;
		case "information":
			return 2;
		case "hint":
			return 3;
		default:
			return 4;
	}
}
