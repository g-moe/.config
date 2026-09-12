import assert from "node:assert/strict";

interface Sample {
	name: string;
	status: string;
	latency?: { elapsedMs: number };
}

export function checkBudget(elapsedMs: number, budgetMs: number) {
	assert.ok(
		Number.isFinite(elapsedMs) && elapsedMs >= 0 && elapsedMs <= budgetMs,
		`Latency ${elapsedMs}ms exceeds ${budgetMs}ms budget`,
	);
}

// Only numbered warm repetitions belong to a benchmark set. A lifecycle
// case such as repeat-maximize must still pass its own per-case time limit.
export function comparePerformance(
	cases: Sample[],
	baseline: Record<string, number>,
) {
	const groups = new Map<string, number[]>();

	for (const sample of cases.filter((c) => / \/ repeat-\d+$/.test(c.name))) {
		assert.equal(sample.status, "PASS");

		const key = sample.name.split(" / repeat-")[0];
		const values = groups.get(key) ?? [];

		assert.ok(
			Number.isFinite(sample.latency?.elapsedMs),
			"Missing latency sample",
		);
		values.push(sample.latency!.elapsedMs);
		groups.set(key, values);
	}

	assert.equal(
		groups.size,
		4,
		"Require both commands from Search and Explorer",
	);

	return Array.from(groups, ([name, values]) => {
		assert.equal(values.length, 20);

		const baselineP95 = baseline[name];

		assert.ok(
			Number.isFinite(baselineP95) && baselineP95 >= 0,
			"Missing or invalid baseline",
		);

		const p95 = percentile(values, 0.95);

		assert.ok(
			p95 <= baselineP95 + 20,
			`${name}: p95 ${p95}ms exceeds baseline ${baselineP95}ms + 20ms`,
		);

		return {
			name,
			median: percentile(values, 0.5),
			p95,
			baselineP95,
			max: Math.max(...values),
		};
	});
}

// Use the nearest rank, matching the saved baseline, without changing samples.
function percentile(values: number[], fraction: number) {
	return values.slice().sort((a, b) => a - b)[
		Math.ceil(values.length * fraction) - 1
	];
}
