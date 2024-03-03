local Job = require("plenary.job")
local utils = require("bit-nvim.utils")

local M = {}

M.get_current_repo = function(cwd)
	local result = Job:new({
		command = "git",
		args = { "config", "--get", "remote.origin.url" },
		cwd = cwd,
	}):sync()

	result = table.concat(result, "")
	result = string.gsub(result, "\n$", "")

	local workspace, repo = string.match(result, "bitbucket.org[:/](.-)/(.-).git")

	if workspace and repo then
		return { workspace = workspace, repo = repo }
	else
		utils.print_error("Failed to get current repo")
		return nil
	end
end

M.checkout_pr = function(cwd, branch)
	utils.print_warn("Checking out PR...")

	Job:new({
		command = "bash",
		args = { "-c", string.format("git fetch && git checkout %s && git pull", branch) },
		cwd = cwd,
		on_exit = function(j)
			print(table.concat(j:result(), ""))
		end,
	}):start()
end

return M
