function Linemode:custom()
	local btime = math.floor(self._file.cha.btime or 0)
	if btime == 0 then
		btime = ""
	elseif os.date("%Y", btime) == os.date("%Y") then
		btime = os.date("%m/%d %H:%M", btime)
	else
		btime = os.date("%y/%m/%d %H:%M", btime)
	end

  local mtime = math.floor(self._file.cha.mtime or 0)
	if mtime == 0 then
		mtime = ""
	elseif os.date("%Y", mtime) == os.date("%Y") then
		mtime = os.date("%m/%d %H:%M", mtime)
	else
		mtime = os.date("%y/%m/%d %H:%M", mtime)
	end

	local size = self._file:size()
	return string.format("%s|%s|%s", size and ya.readable_size(size) or "-", btime, mtime)
end

require("zoxide"):setup {
	update_db = true,
}

-- Plugin auto-installer
local function ensure_plugin(repo, name)
	local plugin_path = os.getenv("HOME") .. "/.config/yazi/plugins/" .. name
	local check_cmd = string.format("[ -d %s ]", plugin_path)
	local exists = os.execute(check_cmd)
	if not exists then
		ya.notify {
			title = "Plugin Installer",
			content = string.format("Installing %s...", name),
			timeout = 3,
		}
		local clone_cmd = string.format("git clone %s %s", repo, plugin_path)
		local success = os.execute(clone_cmd)
		if success then
			ya.notify {
				title = "Plugin Installer",
				content = string.format("%s installed successfully", name),
				timeout = 3,
				level = "info",
			}
		else
			ya.notify {
				title = "Plugin Installer",
				content = string.format("Failed to install %s", name),
				timeout = 5,
				level = "error",
			}
		end
	end
end

ensure_plugin("https://github.com/stelcodes/bunny.yazi", "bunny.yazi")

require("bunny"):setup({
	hops = {
		{ key = "h",          path = "~",                          desc = "Home" },
		{ key = "c",          path = "~/.config",                  desc = "Config" },
		{ key = "l",          path = "~/.local",                   desc = "Local share" },
		{ key = "d",          path = "~/Downloads",                desc = "Downloads" },
		{ key = "g",          path = "~/Library/CloudStorage/",    desc = "Google Drive" },
	},
	desc_strategy = "path",
	ephemeral = true,
	tabs = true,
	notify = false,
	fuzzy_cmd = "fzf",
})
