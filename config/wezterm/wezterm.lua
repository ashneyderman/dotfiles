local wezterm = require("wezterm")
local config = require("config")
local act = wezterm.action

require("events")

-- Apply color scheme based on the WEZTERM_THEME environment variable
local themes = {
	nord = "Nord (Gogh)",
	onedark = "One Dark (Gogh)",
}
local success, stdout, stderr = wezterm.run_child_process({ os.getenv("SHELL"), "-c", "printenv WEZTERM_THEME" })
local selected_theme = stdout:gsub("%s+", "") -- Remove all whitespace characters including newline
config.color_scheme = themes[selected_theme]

wezterm.on("update-right-status", function(window, pane)
	window:set_right_status(window:active_workspace())
end)

config.default_prog = { 'zsh', '-l' }

config.keys = {
	-- Prompt for a name to use for a new workspace and switch to it.
	{
		key = "N",
		mods = "SHIFT|CTRL|ALT",
		action = act.PromptInputLine({
			description = wezterm.format({
				{ Attribute = { Intensity = "Bold" } },
				{ Foreground = { AnsiColor = "Fuchsia" } },
				{ Text = "Enter name for new workspace" },
			}),
			action = wezterm.action_callback(function(window, pane, line)
				-- line will be `nil` if they hit escape without entering anything
				-- An empty string if they just hit enter
				-- Or the actual line of text they wrote
				if line then
					window:perform_action(
						act.SwitchToWorkspace({
							name = line,
						}),
						pane
					)
				end
			end),
		}),
	},
	{ key = "L", mods = "CTRL", action = act.ShowDebugOverlay },
	{ key = "W", mods = "CTRL|ALT", action = act.CloseCurrentPane({ confirm = true }) },
	{ key = "[", mods = "CTRL|ALT", action = act.SwitchWorkspaceRelative(1) },
	{ key = "]", mods = "CTRL|ALT", action = act.SwitchWorkspaceRelative(-1) },
	{ key = "LeftArrow", mods = "ALT", action = act.SendKey({ key = "b", mods = "ALT" }) },
	{ key = "RightArrow", mods = "ALT", action = act.SendKey({ key = "f", mods = "ALT" }) },
	{ key = "LeftArrow", mods = "CMD", action = act.SendKey({ key = "A", mods = "CTRL" }) },
	{ key = "RightArrow", mods = "CMD", action = act.SendKey({ key = "E", mods = "CTRL" }) },
	{ key = "Backspace", mods = "CMD", action = act.SendKey({ key = "U", mods = "CTRL" }) },
}

return config
