import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const THEME_ENV_VAR = "DOTFILES_THEME";

function getStartupTheme(): string | undefined {
	const theme = process.env[THEME_ENV_VAR]?.trim();
	return theme || undefined;
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		const theme = getStartupTheme();
		if (!theme || !ctx.hasUI) return;

		if (!ctx.ui.getTheme(theme)) {
			ctx.ui.notify(`${THEME_ENV_VAR}=${theme}: theme is not loaded`, "warning");
			return;
		}

		const result = ctx.ui.setTheme(theme);
		if (!result.success) {
			ctx.ui.notify(`${THEME_ENV_VAR}=${theme}: ${result.error}`, "warning");
		}
	});
}
