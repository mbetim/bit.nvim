local Job = require("plenary.job")

local M = {}

M.print_warn = function(message)
	vim.api.nvim_echo({ { message, "WarningMsg" } }, false, {})
end

M.print_error = function(message)
	vim.api.nvim_err_writeln(message)
end

M._open_on_browser = function(url)
	local cwd = vim.loop.cwd()

	Job:new({
		command = "open",
		args = { url },
		cwd = cwd,
	}):start()
end

return M
