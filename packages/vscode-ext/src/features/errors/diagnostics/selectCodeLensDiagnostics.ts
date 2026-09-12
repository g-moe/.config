import {
	compareSelectableDiagnostics,
	type SelectableDiagnostic,
} from "./selectDiagnostic";

export function selectCodeLensDiagnostics<TDiagnostic>(
	diagnostics: readonly SelectableDiagnostic<TDiagnostic>[],
): TDiagnostic[] {
	const groupedDiagnostics = new Map<
		number,
		SelectableDiagnostic<TDiagnostic>[]
	>();

	for (const diagnostic of diagnostics) {
		const line = diagnostic.range.start.line;
		const lineDiagnostics = groupedDiagnostics.get(line);

		if (lineDiagnostics) {
			lineDiagnostics.push(diagnostic);
			continue;
		}

		groupedDiagnostics.set(line, [diagnostic]);
	}

	return [...groupedDiagnostics.entries()]
		.sort(([leftLine], [rightLine]) => leftLine - rightLine)
		.map(
			([, lineDiagnostics]) =>
				[...lineDiagnostics].sort(compareSelectableDiagnostics)[0],
		)
		.filter(
			(diagnostic): diagnostic is SelectableDiagnostic<TDiagnostic> =>
				diagnostic !== undefined,
		)
		.map((diagnostic) => diagnostic.diagnostic);
}
