import type * as vscode from "vscode";

// The service uses this small contract in both VS Code and its unit tests.
export type Terminal = Pick<
	vscode.Terminal,
	"name" | "creationOptions" | "processId" | "exitStatus"
>;

// Saved per workspace; process identity is optional when the OS cannot read it.
export interface TerminalState {
	ownerId: string;
	process?: { id: number; start: string };
}

// The adapter supplies VS Code state and OS queries without coupling the
// lifecycle service to the editor or a concrete process implementation.
export interface TerminalHost<T extends Terminal> {
	terminals(): readonly T[];
	create(options: vscode.TerminalOptions): T;
	onClose(listener: (terminal: T) => void): vscode.Disposable;

	load(): TerminalState | undefined;
	save(state: TerminalState): PromiseLike<void>;

	processStart(id: number): Promise<string | undefined>;
	processAlive(id: number): boolean;
}
