local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local Job = require("plenary.job")
local config = require("bit-nvim.config")

local M = {}

local cwd = vim.loop.cwd()

local function print_error(message)
	vim.api.nvim_err_writeln(message)
end

local function get_current_repo()
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

local function fetch_prs(workspace, repo, token)
	local result = Job:new({
		command = "curl",
		args = {
			"-s",
			"-H",
			string.format("Authorization: Basic %s", token),
			string.format("https://api.bitbucket.org/2.0/repositories/%s/%s/pullrequests", workspace, repo),
		},
		cwd = cwd,
	}):sync()

	result = table.concat(result, "")

	local ok, data = pcall(vim.fn.json_decode, result)

	if not ok or not data then
		print_error("Bitbucket response: " .. result)
		return nil
	end

	if data and data.error and data.error.message then
		print_error(data.error.message)
		return nil
	end

	local prs = {}
	for _, pr in ipairs(data.values) do
		table.insert(prs, {
			title = pr.title,
			branch = pr.source.branch.name,
			id = pr.id,
		})
	end

	return prs
end

local function checkout_pr(branch)
	Job:new({ command = "git", args = { "fetch" }, cwd = cwd }):sync()

	local checkout_result = Job:new({ command = "git", args = { "checkout", branch }, cwd = cwd }):sync()
	local pull_result = Job:new({ command = "git", args = { "pull" }, cwd = cwd }):sync()

	print(table.concat(checkout_result, "") .. "\n" .. table.concat(pull_result, ""))
end

M.setup = function()
	local configs, _ = config.load_configs()

	if configs and configs.token and vim.trim(configs.token) ~= "" then
		return nil
	end

	local token = vim.fn.inputsecret("Bitbucket token: ")

	if vim.trim(token) == "" then
		print("A token is required")
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

	vim.api.nvim_echo({ { "Fetching PRs...", "WarningMsg" } }, false, {})

	local result = get_current_repo()

	if not result then
		return nil
	end

	local prs = fetch_prs(result.workspace, result.repo, token)

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
end

return M
