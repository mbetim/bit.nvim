local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local Job = require("plenary.job")
local config = require("bit-nvim.config")

local M = {}

local cwd = vim.loop.cwd()

local function print_warn(message)
	vim.api.nvim_echo({ { message, "WarningMsg" } }, false, {})
end

local function print_error(message)
	vim.api.nvim_err_writeln(message)
end

M._get_current_repo = function()
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
		print("Failed to get current repo")
		return nil
	end
end

M._fetch_prs = function(workspace, repo, token, callback)
	Job:new({
		command = "curl",
		args = {
			"-s",
			"-H",
			string.format("Authorization: Basic %s", token),
			string.format("https://api.bitbucket.org/2.0/repositories/%s/%s/pullrequests", workspace, repo),
		},
		cwd = cwd,
		on_exit = function(j)
			local result = j:result()
			result = table.concat(result, "")

			vim.schedule(function()
				local ok, data = pcall(vim.fn.json_decode, result)

				if not ok or not data then
					print_error("Bitbucket response: " .. data)
					return callback(nil)
				end

				if data and data.error and data.error.message then
					print_error(data.error.message)
					return callback(nil)
				end

				local prs = {}
				for _, pr in ipairs(data.values) do
					table.insert(prs, {
						title = pr.title,
						branch = pr.source.branch.name,
						id = pr.id,
					})
				end

				return callback(prs)
			end)
		end,
	}):start()
end

local function checkout_pr(branch)
	print_warn("Checking out PR...")

	Job:new({
		command = "bash",
		args = { "-c", string.format("git fetch && git checkout %s && git pull", branch) },
		cwd = cwd,
		on_exit = function(j)
			print(table.concat(j:result(), ""))
		end,
	}):start()
end

M.setup = function()
	local configs, _ = config.load_configs()

	if configs and configs.token and vim.trim(configs.token) ~= "" then
		return nil
	end

	local token = vim.fn.inputsecret("Bitbucket token: ")

	if vim.trim(token) == "" then
		print_error("A token is required")
		return nil
	end

	local _, err
	config.write_config({ token = token })

	if not err then
		print("Token saved")
	end
end

M.list_prs = function(opts)
	local configs = config.load_configs()

	if not configs or not configs.token then
		print("A token is required to list the PRs")
		return nil
	end

	local token = configs.token

	print_warn("Fetching PRs from Bitbucket...")

	local result = M._get_current_repo()

	if not result then
		return nil
	end

	M._fetch_prs(result.workspace, result.repo, token, function(prs)
		if not prs then
			return nil
		end

		opts = opts or {}

		pickers
			.new(opts, {
				prompt_title = "Bitbucket PRs",
				finder = finders.new_table({
					results = prs,
					entry_maker = function(entry)
						return {
							value = entry,
							display = entry.title,
							ordinal = entry.title,
						}
					end,
				}),
				sorter = conf.generic_sorter(prs),
				attach_mappings = function(prompt_bufnr)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)

						local selection = action_state.get_selected_entry()
						checkout_pr(selection.value.branch)
					end)
					return true
				end,
			})
			:find()
	end)
end

return M
