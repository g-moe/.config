import assert from "node:assert/strict";
import test from "node:test";
import { checkBudget, comparePerformance } from "./performance";

const samples = (elapsedMs: number) =>
	[
		"focus / search",
		"focus / explorer",
		"maximize / search",
		"maximize / explorer",
	].flatMap((name) =>
		Array.from({ length: 20 }, (_, i) => ({
			name: `${name} / repeat-${i + 1}`,
			status: "PASS",
			latency: { elapsedMs },
		})),
	);

const baseline = (p95: number) =>
	Object.fromEntries(
		[
			"focus / search",
			"focus / explorer",
			"maximize / search",
			"maximize / explorer",
		].map((name) => [name, p95]),
	);

test("latency budget rejects slow, missing, and invalid measurements", () => {
	checkBudget(500, 500);

	for (const elapsed of [501, NaN, -1, Infinity]) {
		assert.throws(() => checkBudget(elapsed, 500));
	}
});

test("relative guard rejects a slowdown even below the absolute budget", () => {
	assert.equal(comparePerformance(samples(60), baseline(50)).length, 4);
	assert.throws(
		() => comparePerformance(samples(71), baseline(50)),
		/exceeds baseline/,
	);
	assert.throws(() => comparePerformance(samples(50).slice(1), baseline(50)));
});

test("lifecycle repeat-maximize is not a numbered benchmark sample", () => {
	const cases = [
		...samples(50),
		{
			name: "lifecycle / repeat-maximize",
			status: "PASS",
			latency: { elapsedMs: 60 },
		},
	];

	assert.equal(comparePerformance(cases, baseline(50)).length, 4);
});
