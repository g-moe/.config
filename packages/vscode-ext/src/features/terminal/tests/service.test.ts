import assert from "node:assert/strict";
import test from "node:test";
import type * as vscode from "vscode";

import { TerminalService } from "../service";
import { readProcessStart } from "../process";
import type { TerminalHost, TerminalState } from "../contracts";

type FakeTerminal = {
	name: string;
	creationOptions: vscode.TerminalOptions;
	processId: Promise<number | undefined>;
	exitStatus: vscode.TerminalExitStatus | undefined;
};

// Keep host state and process identity explicit so startup, reload, and failed
// saves can be tested without starting VS Code or a real shell.
function fixture(initial?: TerminalState) {
	let state = initial;
	let listener: ((terminal: FakeTerminal) => void) | undefined;
	let created = 0;
	const terminals: FakeTerminal[] = [];
	const starts = new Map<number, string>([[42, "first process"]]);
	const add = (
		name = "other",
		id = 42,
		options: vscode.TerminalOptions = {},
	) => {
		const terminal: FakeTerminal = {
			name,
			creationOptions: options,
			processId: Promise.resolve(id),
			exitStatus: undefined,
		};

		terminals.push(terminal);

		return terminal;
	};
	const host: TerminalHost<FakeTerminal> = {
		terminals: () => terminals,
		create: (options) => {
			created++;

			return add(options.name, 42, options);
		},
		onClose: (callback) => {
			listener = callback;

			return {
				dispose: () => {
					listener = undefined;
				},
			};
		},
		load: () => state,
		save: async (value) => {
			state = structuredClone(value);
		},
		processStart: async (id) => starts.get(id),
		processAlive: () => true,
	};

	return {
		host,
		add,
		starts,
		terminals,
		created: () => created,
		state: () => state,
		listening: () => listener !== undefined,
		close: (terminal: FakeTerminal) => {
			terminals.splice(terminals.indexOf(terminal), 1);
			listener?.(terminal);
		},
	};
}

test("concurrent requests create one shell and later calls reuse it", async () => {
	const f = fixture();
	const service = new TerminalService(f.host);
	const [first, second] = await Promise.all([
		service.getTerminal(),
		service.getTerminal(),
	]);

	assert.equal(first, second);
	assert.equal(await service.getTerminal(), first);
	assert.equal(f.created(), 1);
	service.dispose();
});

test("a closed shell is replaced and its stored identity is cleared", async () => {
	const f = fixture();
	const service = new TerminalService(f.host);
	const first = await service.getTerminal();

	f.close(first);
	assert.equal(f.state()?.process, undefined);
	assert.notEqual(await service.getTerminal(), first);
	assert.equal(f.created(), 2);
	service.dispose();
});

test("reload finds the same process without an environment marker", async () => {
	const f = fixture({
		ownerId: "owned",
		process: { id: 42, start: "first process" },
	});
	const restored = f.add("renamed terminal");
	const service = new TerminalService(f.host);

	assert.equal(await service.getTerminal(), restored);
	assert.equal(f.created(), 0);
	service.dispose();
});

test("a reused process ID is not accepted as the owned shell", async () => {
	const f = fixture({
		ownerId: "owned",
		process: { id: 42, start: "old process" },
	});
	const unrelated = f.add();
	const service = new TerminalService(f.host);

	assert.notEqual(await service.getTerminal(), unrelated);
	assert.equal(f.created(), 1);
	assert.ok(f.terminals.includes(unrelated));
	service.dispose();
});

test("an unavailable process start value does not match a restored terminal", async () => {
	const f = fixture({
		ownerId: "owned",
		process: { id: 42, start: "first process" },
	});

	f.starts.clear();

	const unrelated = f.add();
	const service = new TerminalService(f.host);

	assert.notEqual(await service.getTerminal(), unrelated);
	service.dispose();
});

test("duplicate names fail before creating another shell, then recover", async () => {
	const f = fixture();
	const other = f.add("better-vscode");
	const service = new TerminalService(f.host);

	await assert.rejects(service.getTerminal(), /same name/);
	assert.equal(f.created(), 0);
	other.name = "other";
	await service.getTerminal();
	assert.equal(f.created(), 1);
	service.dispose();
});

test("slow startup times out and retries the same terminal", async () => {
	const f = fixture();
	const terminal = f.add("better-vscode", 42, {
		env: { BETTER_VSCODE_TERMINAL_ID: "owned" },
	});

	f.host.load = () => ({ ownerId: "owned" });
	terminal.processId = new Promise(() => {});

	const service = new TerminalService(f.host, 20);

	await assert.rejects(service.getTerminal(), /ready in time/);
	terminal.processId = Promise.resolve(42);
	assert.equal(await service.getTerminal(), terminal);
	assert.equal(f.created(), 0);
	service.dispose();
});

test("closing during process lookup fails and the next request can recover", async () => {
	const f = fixture();

	f.host.processStart = async () => {
		f.close(f.terminals[0]);

		return "first process";
	};

	const service = new TerminalService(f.host);

	await assert.rejects(service.getTerminal(), /terminal closed/);
	f.host.processStart = async () => "new process";
	await service.getTerminal();
	assert.equal(f.created(), 2);
	service.dispose();
});

test("disposal removes the listener and cancels a pending startup", async () => {
	const f = fixture({ ownerId: "owned" });
	const terminal = f.add("better-vscode", 42, {
		env: { BETTER_VSCODE_TERMINAL_ID: "owned" },
	});

	terminal.processId = new Promise(() => {});

	const service = new TerminalService(f.host);
	const pending = service.getTerminal();

	await Promise.resolve();
	service.dispose();
	await assert.rejects(pending);
	assert.equal(f.listening(), false);
	await assert.rejects(service.getTerminal());
	assert.equal(f.created(), 0);
});

test("the process identity reader returns a stable start value for this process", async () => {
	const first = await readProcessStart(process.pid);

	assert.ok(first);
	assert.equal(await readProcessStart(process.pid), first);
	assert.equal(await readProcessStart(-1), undefined);
});

test("a dead shell left in the API list is replaced without a close event", async () => {
	const f = fixture();
	const service = new TerminalService(f.host);
	const first = await service.getTerminal();

	first.processId = Promise.resolve(41);
	f.host.processAlive = (id) => id !== 41;

	const second = await service.getTerminal();

	assert.notEqual(second, first);
	assert.ok(f.terminals.includes(first), "simulate the stale API entry");
	assert.equal(first.exitStatus, undefined);
	assert.equal(await service.getTerminal(), second);
	assert.equal(f.created(), 2);
	service.dispose();
});

test("an ended same-name shell does not block creation after reload", async () => {
	const f = fixture({ ownerId: "owned" });
	const stale = f.add("better-vscode", 41);

	f.host.processAlive = (id) => id !== 41;

	const service = new TerminalService(f.host);

	assert.notEqual(await service.getTerminal(), stale);
	assert.equal(f.created(), 1);
	service.dispose();
});

test("an unavailable process start does not repeat lookup or save on warm calls", async () => {
	const f = fixture();
	let lookups = 0;
	let saves = 0;

	f.host.processStart = async () => {
		lookups++;

		return undefined;
	};

	const save = f.host.save;

	f.host.save = async (state) => {
		saves++;
		await save(state);
	};

	const service = new TerminalService(f.host);

	try {
		const terminal = await service.getTerminal();

		assert.equal(lookups, 1);
		assert.equal(saves, 2);

		for (let i = 0; i < 10; i++) {
			assert.equal(await service.getTerminal(), terminal);
		}

		assert.equal(
			lookups,
			1,
			"warm focus must not repeat an external process lookup",
		);
		assert.equal(saves, 2, "warm focus must not repeat state writes");
		assert.equal(f.created(), 1);
	} finally {
		service.dispose();
	}
});

test("a failed final state save is retried before the terminal is cached", async () => {
	const f = fixture();
	let saves = 0;
	const save = f.host.save;

	f.host.save = async (state) => {
		saves++;

		if (saves === 2) {
			throw new Error("state save failed");
		}

		await save(state);
	};

	const service = new TerminalService(f.host);

	try {
		await assert.rejects(service.getTerminal(), /state save failed/);

		const terminal = f.terminals[0];

		assert.equal(await service.getTerminal(), terminal);
		assert.equal(saves, 4, "retry must complete the failed state save");
		assert.ok(f.state()?.process);
		assert.equal(await service.getTerminal(), terminal);
		assert.equal(saves, 4);
		assert.equal(f.created(), 1);
	} finally {
		service.dispose();
	}
});
