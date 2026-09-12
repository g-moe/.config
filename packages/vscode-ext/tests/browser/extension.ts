import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import * as vscode from "vscode";
import { checkBudget, comparePerformance } from "./performance";
import {
	run,
	snapshot,
	until,
	type Checkpoint,
} from "../../src/features/terminal/tests/integration";

export function activate(context: vscode.ExtensionContext) {
	const reportPath = process.env.BETTER_VSCODE_TEST_REPORT!;
	const proofPath = `${reportPath}.input`;
	const status = vscode.window.createStatusBarItem(
		vscode.StatusBarAlignment.Left,
		10000,
	);
	// F19 acknowledges the starting state; shell output confirms the outcome.
	let continued = false;
	let running = false;

	context.subscriptions.push(
		status,
		vscode.commands.registerCommand("better-vscode.tests.continue", () => {
			continued = true;
		}),
	);
	context.subscriptions.push(
		vscode.commands.registerCommand(
			"better-vscode.tests.terminal",
			async () => {
				if (running) {
					throw new Error("A test run is already active");
				}

				running = true;

				const report = {
					status: "RUNNING",
					performance: [] as ReturnType<typeof comparePerformance>,
					vscode: vscode.version,
					server: JSON.parse(
						readFileSync(
							join(dirname(process.execPath), "product.json"),
							"utf8",
						),
					).version,
					platform: process.platform,
					proofPath,
					cases: [] as {
						name: string;
						status: string;
						before?: Checkpoint;
						after?: Checkpoint;
						error?: string;
						tabs?: ReturnType<typeof snapshot>;
						latency?: { elapsedMs: number; budgetMs: number; source: string };
					}[],
				};
				const save = () =>
					writeFileSync(reportPath, JSON.stringify(report, null, 2));

				save();

				try {
					if (report.server !== process.env.BETTER_VSCODE_TEST_VERSION) {
						throw new Error("Unexpected server version");
					}

					await run({
						start(name) {
							report.cases.push({ name, status: "RUNNING" });
							save();
						},
						// Clear old proof before each step so a previous case cannot pass this one.
						async checkpoint(check) {
							const current = report.cases.at(-1)!;

							current[check.phase] = check;
							continued = false;
							writeFileSync(proofPath, "");
							// Field order matches checkpoint() in the browser adapter.
							status.text = [
								"BVTEST",
								report.cases.length,
								check.phase,
								check.column,
								check.groups,
								Number(check.maximize),
								check.input,
								check.command ?? "",
								check.surface ?? "",
								Number(check.cold ?? false),
								check.elapsedMs ?? "",
								check.budgetMs ?? "",
								check.state ?? "",
							].join(":");
							status.show();
							save();

							if (check.phase === "before") {
								await until(
									() => continued,
									"browser must verify starting state and press F19",
									120000,
								);
							} else {
								await until(
									() => readProof()?.id === report.cases.length,
									"browser must verify layout and type proof into the focused shell",
									120000,
								);
							}

							if (check.phase === "after") {
								const proof = readProof()!;
								const elapsedMs = check.elapsedMs ?? proof.elapsedMs;
								const budgetMs = current.before?.cold
									? 2000
									: (check.budgetMs ?? 500);

								current.latency = {
									elapsedMs,
									budgetMs,
									source:
										check.elapsedMs === undefined
											? "browser trigger to ready (includes tool overhead)"
											: "API command batch",
								};
								save();
								checkBudget(elapsedMs, budgetMs);
							}

							status.hide();
						},
						async pass() {
							report.cases.at(-1)!.status = "PASS";
							save();
						},
					});
					// Completion requires both behavior checks and the relative timing guard.
					report.performance = comparePerformance(
						report.cases,
						JSON.parse(
							readFileSync(process.env.BETTER_VSCODE_TEST_BASELINE!, "utf8"),
						),
					);
					report.status = "PASS";
					status.text = `BVTEST:DONE:${report.cases.length}`;
					status.show();
				} catch (error) {
					report.status = "FAIL";

					const current = report.cases.at(-1);

					if (current) {
						current.status = "FAIL";
						current.error = String(error);
						current.tabs = snapshot();
					}

					status.text = `BVTEST:FAIL:${report.cases.length}`;
					status.show();
					throw error;
				} finally {
					running = false;
					save();
				}
			},
		),
	);
}

// The browser types a shell command that writes this file; empty or incomplete
// output means the current step has not completed yet.
function readProof(): { id: number; elapsedMs: number } | undefined {
	try {
		return JSON.parse(
			readFileSync(`${process.env.BETTER_VSCODE_TEST_REPORT}.input`, "utf8"),
		);
	} catch {
		return undefined;
	}
}
