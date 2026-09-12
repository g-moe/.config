// Use the current keyboard focus. F17/F18 bind directly to production commands
// only in the separate test extension. Browser timing includes tool overhead.
const timings = new Map();

// The test extension exposes the current step through its status-bar label.
export async function checkpoint(browser, id, phase) {
	const marker = browser.playwright.getByRole("button", {
		name: new RegExp(`^BVTEST:${id}:${phase}:`),
	});

	await marker.waitFor({ state: "visible", timeoutMs: 20000 });

	const parts = (
		(await marker.getAttribute("aria-label")) || (await marker.innerText())
	).split(":");

	return {
		id,
		phase,
		column: Number(parts[3]),
		groups: Number(parts[4]),
		maximize: parts[5] === "1",
		input: parts[6],
		command: parts[7],
		surface: parts[8],
		cold: parts[9] === "1",
		elapsedMs: parts[10] === "" ? undefined : Number(parts[10]),
		budgetMs: Number(parts[11]) || 500,
		state: parts[12],
	};
}

// Read DOM focus without changing it. Pin controls and sticky state are more
// reliable than the tab label, which VS Code can leave stale after pinning.
export async function readUI(browser) {
	return browser.playwright.evaluate(() => {
		const active = document.activeElement;
		const group = active?.closest(".editor-group-container");

		return {
			input: active?.getAttribute("aria-label"),
			placeholder: active?.getAttribute("placeholder"),
			value: active?.value,
			tree: active?.closest('[role="tree"]')?.getAttribute("aria-label"),
			find: Boolean(active?.closest(".find-widget")),
			scm: Boolean(active?.closest(".scm-view")),
			lockedGroups: document.querySelectorAll(".editor-group-container.locked")
				.length,
			quick: Boolean(active?.closest(".quick-input-widget")),
			tabs: group
				? Array.from(group.querySelectorAll('[role="tab"]')).map((tab) => ({
						label: tab.getAttribute("aria-label"),
						selected: tab.getAttribute("aria-selected") === "true",
						sticky: tab.classList.contains("sticky"),
						unpin: Boolean(
							tab.querySelector('[role="button"][aria-label="Unpin Editor"]'),
						),
					}))
				: [],
			maximized: Boolean(
				group?.querySelector('[aria-label^="Unmaximize Group"]'),
			),
			visibleGroups: Array.from(
				document.querySelectorAll(".editor-group-container"),
			).filter(
				(group) =>
					group.getBoundingClientRect().width > 5 &&
					group.getBoundingClientRect().height > 5,
			).length,
			search: document.querySelector(
				'textarea[aria-label="Search: Type Search Term and press Enter to search"]',
			)?.value,
		};
	});
}

// Starting controls have different focus markers. All outcomes must satisfy
// the same terminal, group, pin, position, and maximize requirements.
export function assertUI(check, ui) {
	const fail = (reason) => {
		throw new Error(
			`${check.id} ${check.phase}: ${reason}: ${JSON.stringify(ui)}`,
		);
	};

	if (check.phase === "before" && check.surface) {
		const valid = {
			editor: ui.input?.includes(check.input),
			scm: ui.scm && ui.tree === "Source Control Management",
			search:
				ui.input === "Search: Type Search Term and press Enter to search" &&
				ui.value === "Fixture",
			explorer: ui.tree === "Files Explorer",
			"search-results": ui.tree?.endsWith(" - Search: Fixture"),
			find: ui.find && ui.value === "Fixture",
			output: ui.input?.includes("Better VS Code Test Output"),
			"panel-terminal":
				ui.input?.includes("Other Shell") && ui.tabs.length === 0,
			"quick-open": ui.quick && ui.value === "fixture",
			rename:
				ui.input?.includes("file name") && ui.value?.startsWith("fixture-"),
		};

		if (!valid[check.surface]) {
			fail("wrong starting keyboard focus");
		}

		if (check.state?.includes("locked") && ui.lockedGroups !== 1) {
			fail("starting editor group must be locked");
		}

		if (
			check.state?.endsWith("maximized") &&
			ui.visibleGroups !==
				(check.state.startsWith("panel") || check.state.startsWith("sidebar")
					? 0
					: 1)
		) {
			fail("starting view must be maximized");
		}

		return;
	}

	if (!ui.input?.includes(check.input)) {
		fail("wrong keyboard focus");
	}

	if (
		ui.visibleGroups !== (check.maximize && check.groups > 1 ? 1 : check.groups)
	) {
		fail("wrong visible group count");
	}

	if (
		check.groups > 1 &&
		!ui.tabs.some(
			(tab) =>
				tab.selected && tab.label?.includes(`Editor Group ${check.column}`),
		)
	) {
		fail("wrong active group");
	}

	if (check.phase === "after") {
		const first = ui.tabs[0];

		if (
			!first?.label?.startsWith(check.input) ||
			!first.selected ||
			!first.sticky ||
			!first.unpin
		) {
			fail("terminal must be first, selected, and pinned");
		}

		if (ui.maximized !== (check.maximize && check.groups > 1)) {
			fail("wrong maximized state");
		}
	}
}

export async function focusSurface(browser, keyboard, surface, input) {
	if (surface === "search" || surface === "search-results") {
		await keyboard.pressKey("super+shift+f");
		await browser.playwright
			.getByRole("textbox", {
				name: "Search: Type Search Term and press Enter to search",
				exact: true,
			})
			.fill("Fixture");

		if (surface === "search-results") {
			await keyboard.pressKey("Return");
			await browser.playwright
				.getByRole("treeitem", { name: /fixture-1.txt/ })
				.first()
				.click();
		}
	} else if (surface === "explorer" || surface === "rename") {
		await keyboard.pressKey("super+shift+e");

		if (surface === "rename") {
			await browser.playwright
				.getByRole("treeitem", { name: input, exact: true })
				.click({ button: "right" });
			await browser.playwright
				.getByRole("menuitem", { name: /^Rename\.\.\./ })
				.click();
		} else {
			await browser.playwright
				.getByRole("tree", { name: "Files Explorer", exact: true })
				.click();
		}
	} else if (surface === "scm") {
		await palette(browser, keyboard, "Source Control: Focus on Changes View");
		await keyboard.pressKey("Return");
	} else if (surface === "find") {
		await keyboard.pressKey("super+f");
		await keyboard.pressKey("super+a");
		await keyboard.typeText("Fixture");
	} else if (surface === "quick-open") {
		await keyboard.pressKey("super+p");
		await keyboard.typeText("fixture");
	} else if (surface === "panel-terminal") {
		await palette(browser, keyboard, "Terminal: Focus Terminal");
		await keyboard.pressKey("Return");
		await browser.playwright
			.locator('[aria-label^="Terminal"][aria-label*="Other Shell"]:focus')
			.waitFor({ state: "visible", timeoutMs: 5000 });
	} else if (surface === "output") {
		await palette(browser, keyboard, "Output: Focus on Output View");
		await keyboard.pressKey("Return");
		await browser.playwright
			.locator('[aria-label*="Better VS Code Test Output"]:focus')
			.waitFor({ state: "visible", timeoutMs: 5000 });
	}
}

// Select the command but do not run it yet; palette typing is outside timing.
async function palette(browser, keyboard, title) {
	await keyboard.pressKey("super+shift+p");
	await keyboard.typeText(title);
	await browser.playwright
		.getByRole("option", { name: new RegExp(`^${title}(,|$)`) })
		.waitFor({ state: "visible", timeoutMs: 5000 });
}

export async function checkCheckpoint(browser, keyboard, id, phase, proofPath) {
	const check = await checkpoint(browser, id, phase);

	if (phase === "before" && check.surface) {
		await focusSurface(browser, keyboard, check.surface, check.input);
	}

	const ui = await readUI(browser);

	assertUI(check, ui);

	if (phase === "before") {
		if (check.command) {
			const maximize = check.command.endsWith("focusAndMaximize");

			if (!check.surface) {
				await palette(
					browser,
					keyboard,
					maximize
						? "better-vscode: terminal - focus & maximize"
						: "better-vscode: terminal - focus",
				);
			}

			// Start timing at dispatch and stop only when the complete outcome is visible.
			const start = performance.now();

			await keyboard.pressKey(
				check.surface ? (maximize ? "F18" : "F17") : "Return",
			);

			const expected = {
				...check,
				phase: "after",
				column: 1,
				input: "better-vscode",
				maximize: maximize || Boolean(check.state?.startsWith("owned-")),
			};
			let ready;

			while (true) {
				ready = await readUI(browser);

				try {
					assertUI(expected, ready);
					break;
				} catch (error) {
					if (performance.now() - start > (check.cold ? 2000 : 500)) {
						throw error;
					}
				}
			}

			const elapsedMs = performance.now() - start;

			if (elapsedMs > (check.cold ? 2000 : 500)) {
				throw new Error(`Case ${id}: ${elapsedMs}ms exceeds latency limit`);
			}

			timings.set(id, elapsedMs);

			if (
				ui.search !== undefined &&
				ready.search !== undefined &&
				ui.search !== ready.search
			) {
				throw new Error("Command changed the search query");
			}
		}

		await keyboard.pressKey("F19");
	} else {
		if (!/^[a-zA-Z0-9/_.-]+$/.test(proofPath)) {
			throw new Error("Unexpected proof path");
		}

		const elapsedMs = check.elapsedMs ?? timings.get(id);

		if (!Number.isFinite(elapsedMs)) {
			throw new Error("Missing latency sample");
		}

		// Type through the current focus. A locator that focuses the terminal here
		// would conceal a broken command. Only the shell may produce this proof.
		await keyboard.typeText(
			`printf '%s' '${JSON.stringify({ id, elapsedMs })}' > '${proofPath}'`,
		);
		await keyboard.pressKey("Return");
	}

	return { ...check, ui, elapsedMs: check.elapsedMs ?? timings.get(id) };
}
