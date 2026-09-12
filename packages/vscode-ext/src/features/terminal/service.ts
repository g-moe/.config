import { randomUUID } from "node:crypto";
import type * as vscode from "vscode";

import type { Terminal, TerminalHost, TerminalState } from "./contracts";

const OWNER_ENV = "BETTER_VSCODE_TERMINAL_ID";
const TERMINAL_NAME = "better-vscode";

// Owns shell identity and startup. Editor placement belongs to editor.ts.
export class TerminalService<T extends Terminal> {
	private state: TerminalState;
	private terminal?: T;
	private terminalReady = false;
	private readonly closedProcesses = new WeakSet<T>();
	private pending?: Promise<T>;
	private readonly closed: vscode.Disposable;
	private readonly controller = new AbortController();

	constructor(
		private readonly host: TerminalHost<T>,
		private readonly timeoutMs = 5000,
	) {
		this.state = host.load() ?? { ownerId: randomUUID() };

		this.closed = host.onClose((terminal) => {
			if (terminal === this.terminal) {
				this.terminal = undefined;
				this.terminalReady = false;
				this.state = { ownerId: this.state.ownerId };

				void Promise.resolve(host.save(this.state)).catch(console.error);
			}
		});
	}

	get signal(): AbortSignal {
		return this.controller.signal;
	}

	// Share one startup operation when several commands arrive together.
	getTerminal(): Promise<T> {
		if (!this.pending) {
			this.pending = this.acquire().finally(() => {
				this.pending = undefined;
			});
		}

		return this.pending;
	}

	dispose() {
		this.controller.abort();
		this.closed.dispose();
	}

	private async acquire(): Promise<T> {
		this.signal.throwIfAborted();

		// A panel/editor round trip can leave a closed shell in VS Code's list.
		// Reject only a process that the OS confirms is gone.
		for (const candidate of this.host.terminals()) {
			if (
				candidate === this.terminal ||
				candidate.name === (this.terminal?.name ?? TERMINAL_NAME) ||
				this.hasOwnershipMarker(candidate)
			) {
				const id = await this.wait(candidate.processId);

				if (id !== undefined && !this.host.processAlive(id)) {
					this.closedProcesses.add(candidate);
				}
			}
		}

		// Readiness includes a successful save. Missing optional process metadata
		// must not force another external lookup on every warm call.
		if (this.terminal && this.isLive(this.terminal) && this.terminalReady) {
			this.assertUniqueName(this.terminal.name, this.terminal);

			return this.terminal;
		}

		// Persist the owner before creation so a failed startup can reuse its shell.
		this.terminalReady = false;
		await this.wait(this.host.save(this.state));

		const terminals = this.host
			.terminals()
			.filter((terminal) => this.isLive(terminal));
		const marked = terminals.filter((terminal) =>
			this.hasOwnershipMarker(terminal),
		);
		let terminal = marked.length === 1 ? marked[0] : undefined;

		// Restored terminals can lose their creation environment after reload.
		// Match both PID and start time so a reused PID cannot claim another shell.
		if (!terminal && this.state.process) {
			const saved = this.state.process;

			for (const candidate of terminals) {
				const id = await this.wait(candidate.processId);

				if (
					id === saved.id &&
					(await this.wait(this.host.processStart(id))) === saved.start
				) {
					terminal = candidate;
					break;
				}
			}
		}

		if (!terminal && marked.length > 1) {
			throw new Error(
				"More than one terminal has the ownership marker. Close the extra terminal and try again.",
			);
		}

		this.assertUniqueName(terminal?.name ?? TERMINAL_NAME, terminal);
		this.signal.throwIfAborted();
		terminal ??= this.host.create({
			name: TERMINAL_NAME,
			env: { [OWNER_ENV]: this.state.ownerId },
			location: { viewColumn: 1 },
		});
		this.terminal = terminal;

		const id = await this.wait(terminal.processId);
		const start =
			id === undefined
				? undefined
				: await this.wait(this.host.processStart(id));

		this.assertLive(terminal);
		this.state = {
			ownerId: this.state.ownerId,
			process: id !== undefined && start ? { id, start } : undefined,
		};
		await this.wait(this.host.save(this.state));
		this.assertLive(terminal);

		// A failed save must retry acquisition instead of using the cached terminal.
		this.terminalReady = true;

		return terminal;
	}

	private hasOwnershipMarker(terminal: T) {
		const options = terminal.creationOptions;

		return "env" in options && options.env?.[OWNER_ENV] === this.state.ownerId;
	}

	private isLive(terminal: T) {
		return (
			!this.closedProcesses.has(terminal) &&
			terminal.exitStatus === undefined &&
			this.host.terminals().includes(terminal)
		);
	}

	private assertLive(terminal: T) {
		this.signal.throwIfAborted();

		if (!this.isLive(terminal)) {
			throw new Error("The terminal closed. Run the command again.");
		}
	}

	// The stable tab API exposes titles, not terminal IDs. A duplicate title
	// would make editor commands ambiguous even when the shell identity is known.
	private assertUniqueName(name: string, owned?: T) {
		if (
			this.host
				.terminals()
				.some(
					(terminal) =>
						terminal !== owned &&
						this.isLive(terminal) &&
						terminal.name === name,
				)
		) {
			throw new Error(
				"Two terminals have the same name, or the existing terminal cannot be identified. Rename or close the other terminal and try again.",
			);
		}
	}

	// Startup and state storage can stall. All exit paths release the timeout
	// and abort listener, including extension disposal during a pending request.
	private wait<R>(operation: PromiseLike<R>): Promise<R> {
		this.signal.throwIfAborted();

		return new Promise((resolve, reject) => {
			const abort = () => {
				finish();
				reject(new Error("The terminal service stopped."));
			};
			const timer = setTimeout(() => {
				finish();
				reject(
					new Error(
						"The terminal did not become ready in time. Run the command again.",
					),
				);
			}, this.timeoutMs);
			const finish = () => {
				clearTimeout(timer);
				this.signal.removeEventListener("abort", abort);
			};

			this.signal.addEventListener("abort", abort, { once: true });
			Promise.resolve(operation).then(
				(value) => {
					finish();
					resolve(value);
				},
				(error) => {
					finish();
					reject(error);
				},
			);
		});
	}
}
