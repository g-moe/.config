export const BETTER_ERRORS_CONFIG = {
	root: "betterErrors",
	enabled: "enabled",
	includeWorkspaceRelativePath: "includeWorkspaceRelativePath",
	includeSelection: "includeSelection",
	contextLineCount: "contextLineCount",
} as const;

export const BETTER_ERRORS_PROMPT_DEFAULTS = {
	instruction:
		"You are investigating a real editor error in a codebase. Use the diagnostic and project evidence below to find the most likely root cause. Prefer project-specific evidence over generic advice.",
	emptyContextPlaceholder: "<no local context>",
	emptyActiveScopePlaceholder: "<no enclosing scope found>",
	emptyDefinitionPlaceholder: "<no definition found>",
	emptyTypeDefinitionPlaceholder: "<no type definition found>",
	emptyRelatedDiagnosticsPlaceholder: "<no related diagnostics>",
	emptyReferencesPlaceholder: "<no references found>",
	emptyCallHierarchyPlaceholder: "<no call hierarchy available>",
} as const;
