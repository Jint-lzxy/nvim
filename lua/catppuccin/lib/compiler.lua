local path_sep = require("catppuccin").path_sep
local O = require("catppuccin").options
local M = {}

-- Credit: https://github.com/EdenEast/nightfox.nvim
local fmt = string.format

local function inspect(t)
	local list = {}
	for k, v in pairs(t) do
		local q = type(v) == "string" and [["]] or ""
		table.insert(list, fmt([[%s = %s%s%s]], k, q, tostring(v), q))
	end
	table.sort(list)
	return fmt([[{ %s }]], table.concat(list, ", "))
end

function M.compile(flavour)
	local theme = require("catppuccin.lib.mapper").apply(flavour)
	local lines = {
		[[
require("catppuccin").compiled = string.dump(function()
if vim.g.colors_name then vim.cmd("hi clear") end
vim.o.termguicolors = true
vim.g.colors_name = "catppuccin"
local h = vim.api.nvim_set_hl]],
	}
	table.insert(lines, "vim.o.background = " .. (flavour == "latte" and [["light"]] or [["dark"]]))
	if path_sep == "\\" then O.compile_path = O.compile_path:gsub("/", "\\") end

	local tbl = vim.tbl_deep_extend("keep", theme.custom_highlights, theme.integrations, theme.syntax, theme.editor)

	if O.term_colors == true then
		for k, v in pairs(theme.terminal) do
			table.insert(lines, fmt('vim.g.%s = "%s"', k, v))
		end
	end

	local groups = {}
	for group, color in pairs(tbl) do
		if color.style then
			for _, style in pairs(color.style) do
				color[style] = true
				if O.no_italic and style == "italic" then color[style] = false end
				if O.no_bold and style == "bold" then color[style] = false end
			end
		end
		color.style = nil
		if color.link and (theme.custom_highlights[group] and not theme.custom_highlights[group].link) then
			color.link = nil
		end
		local opts = inspect(color)
		groups[opts] = groups[opts] or {}
		table.insert(groups[opts], group)
	end
	for opts, group in pairs(groups) do
		table.sort(group, function(a, b) return #a < #b end)
		for i, v in ipairs(group) do
			if i == 1 then
				table.insert(lines, fmt([[h(0, "%s", %s)]], v, opts))
			else
				table.insert(lines, fmt([[h(0, "%s", { link = "%s" })]], v, group[1]))
			end
		end
	end
	table.insert(lines, "end)")
	if vim.fn.isdirectory(O.compile_path) == 0 then vim.fn.mkdir(O.compile_path, "p") end
	local file = io.open(O.compile_path .. path_sep .. flavour .. "_compiled.lua", "wb")
	local err_path = (path_sep == "/" and "/tmp" or os.getenv "TMP") .. "/catppuccin_error.lua"
	local err = io.open(err_path, "wb")
	err:write(table.concat(lines, "\n"))
	err:close()

	local f = loadstring(table.concat(lines, "\n"), "=")
	if not f then
		local err_path = (path_sep == "/" and "/tmp" or os.getenv "TMP") .. "/catppuccin_error.lua"
		print(string.format(
			[[Catppuccin (error): Most likely some mistake made in your catppuccin config
You can open %s for debugging

If you think this is a bug, kindly open an issue and attach %s file
Below is the error message that we captured:
]],
			err_path,
			err_path
		))
		local err = io.open(err_path, "wb")
		err:write(table.concat(lines, "\n"))
		err:close()
		dofile(err_path)
		return
	end
	f()

	if file then
		file:write(require("catppuccin").compiled)
		file:close()
	else
		print(
			"Permission denied while writing compiled file to "
				.. O.compile_path
				.. path_sep
				.. flavour
				.. "_compiled.lua"
		)
	end
end

return M
