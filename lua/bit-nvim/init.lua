local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local previewers = require("telescope.previewers")
local Job = require("plenary.job")
local config = require("bit-nvim.config")
local git = require("bit-nvim.git")
local utils = require("bit-nvim.utils")

local M = {}

local cwd = vim.loop.cwd()

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
					utils.print_error("Bitbucket response: " .. data)
					return callback(nil)
				end

				if data and data.error and data.error.message then
					utils.print_error(data.error.message)
					return callback(nil)
				end

				local prs = {}
				for _, pr in ipairs(data.values) do
					table.insert(prs, {
						id = pr.id,
						title = pr.title,
						source_branch = pr.source.branch.name,
						destination_branch = pr.destination.branch.name,
						url = pr.links.html.href,
						comments_count = pr.comment_count,
						author = {
							name = pr.author.nickname,
						},
						description = pr.summary.raw,
					})
				end

				return callback(prs)
			end)
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
		utils.print_error("A token is required")
		return nil
	end

	local _, err
	config.write_config({ token = token })

	if not err then
		print("Token saved")
	end
end

local custom_previewer = function()
	return previewers.new_buffer_previewer({
		define_preview = function(self, entry, status)
			vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")

			local lines = {
				"# Title: " .. entry.value.title,
				"",
				string.format("[%s]   [%s]", entry.value.source_branch, entry.value.destination_branch),
				"",
				"**Author:** " .. entry.value.author.name,
				"**Comments count:** " .. entry.value.comments_count,
				"",
				"## Description",
				"",
			}

			local mark_glyph = " "
			local description = string.gsub(entry.value.description, ":white\\_check\\_mark:", mark_glyph)
			description = string.gsub(description, ":white_check_mark:", mark_glyph)
			description = string.gsub(description, ":warning:", " ")

			local previous_line = ""
			for str in string.gmatch(description, "([^\n]*)") do
				str = string.gsub(str, "\u{200C}", "")

				if previous_line == "" and str == "" then
					goto continue
				end

				table.insert(lines, str)

				::continue::
				previous_line = str
			end

			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
		end,
	})
end

M.list_prs = function(opts)
	local configs = config.load_configs()

	if not configs or not configs.token then
		print("A token is required to list the PRs")
		return nil
	end

	local token = configs.token

	local result = git.get_current_repo(cwd)

	if not result then
		return nil
	end

	utils.print_warn("Fetching PRs from Bitbucket...")

	M._fetch_prs(result.workspace, result.repo, token, function(prs)
		if not prs then
			return nil
		end

		opts = opts or {}

		local displayer = entry_display.create({
			separator = " ",
			items = {
				{ width = 5 },
				{ width = 50 },
				{ remaining = true },
			},
		})

		local make_display = function(entry)
			local pr = entry.value

			return displayer({
				{ string.format("#%s", pr.id) },
				{ pr.title },
				{ pr.author.name },
			})
		end

		pickers
			.new(opts, {
				prompt_title = "Bitbucket PRs",
				finder = finders.new_table({
					results = prs,
					entry_maker = function(entry)
						return {
							value = entry,
							display = make_display,
							ordinal = table.concat({ entry.id, entry.title, entry.author.name }, " "),
						}
					end,
				}),
				previewer = custom_previewer(),
				sorter = conf.generic_sorter(prs),
				attach_mappings = function(prompt_bufnr, map)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)

						local selection = action_state.get_selected_entry()
						git.checkout_pr(cwd, selection.value.source_branch)
					end)

					local open_pr_on_brownser = function()
						local selection = action_state.get_selected_entry()
						utils._open_on_browser(selection.value.url)
					end

					map("i", "<C-o>", open_pr_on_brownser)
					map("n", "<C-o>", open_pr_on_brownser)

					return true
				end,
			})
			:find()
	end)
end

return M
