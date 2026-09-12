export const BETTER_ERRORS_COMMAND_PREFIX = "betterErrors";
export const BETTER_ERRORS_DISPLAY_PREFIX = "better-errors";

export const BETTER_ERRORS_COMMANDS = {
	copyError: `${BETTER_ERRORS_COMMAND_PREFIX}.copyError`,
	toggleEnabled: `${BETTER_ERRORS_COMMAND_PREFIX}.toggleEnabled`,
} as const;

export const BETTER_ERRORS_COMMAND_TITLES = {
	copyError: `${BETTER_ERRORS_DISPLAY_PREFIX}: Copy Error`,
	toggleEnabled: `${BETTER_ERRORS_DISPLAY_PREFIX}: Toggle Enabled`,
} as const;
