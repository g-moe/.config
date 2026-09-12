import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

// PID alone is not enough after reload: the OS can reuse it for another process.
export async function readProcessStart(
	id: number,
): Promise<string | undefined> {
	if (!Number.isSafeInteger(id) || id <= 0) {
		return undefined;
	}

	try {
		const result =
			process.platform === "win32"
				? await execFileAsync(
						"powershell.exe",
						[
							"-NoProfile",
							"-NonInteractive",
							"-Command",
							`(Get-Process -Id ${id}).StartTime.ToUniversalTime().Ticks`,
						],
						{ timeout: 3000 },
					)
				: await execFileAsync("ps", ["-p", String(id), "-o", "lstart="], {
						timeout: 3000,
						env: { ...process.env, LC_ALL: "C" },
					});

		return result.stdout.trim() || undefined;
	} catch {
		// An unavailable process identity must never match a saved shell.
		return undefined;
	}
}

export function isProcessAlive(id: number): boolean {
	try {
		// Signal zero checks process existence without sending a termination signal.
		process.kill(id, 0);

		return true;
	} catch (error) {
		// Permission errors do not prove that the process has ended.
		return (error as NodeJS.ErrnoException).code !== "ESRCH";
	}
}
