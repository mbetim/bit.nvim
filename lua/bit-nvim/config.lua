local Path = require("plenary.path")

local M = {}

local file_path = vim.fn.expand("~") .. "/.config/bit/bit-nvim.json"
local default_mode = 438

M.write_config = function(config)
	local ok, data = pcall(vim.fn.json_encode, config)

	if not ok then
		print("Error: Failed to encode config")
		return nil
	end

	local parent = Path:new(file_path):parent().filename

	local ok, err = pcall(vim.fn.mkdir, parent, "p")
	if not ok then
		print("Could not create directory: " .. err)
		return nil, err
	end

	local fd, err, errcode = vim.loop.fs_open(file_path, "w+", default_mode)

	if err or not fd then
		print("Could not open config file: " .. err)
		return nil, errcode
	end

	local size, err, errcode = vim.loop.fs_write(fd, data, 0)
	vim.loop.fs_close(fd)

	if err then
		print("Could not write config file: " .. err)
		return nil, errcode
	end

	return size, nil
end

M.load_configs = function()
	local fd, err, errcode = vim.loop.fs_open(file_path, "r", default_mode)

	if err or not fd then
		if errcode == "ENOENT" then
			return nil, errcode
		end

		print("Error: could not open config file: " .. err)
		return nil, errcode
	end

	local stat, err, errcode = vim.loop.fs_fstat(fd)
	if err or not stat then
		vim.loop.fs_close(fd)
		print("Error: could not stat file: " .. err)
		return nil, errcode
	end

	local content, err, errcode = vim.loop.fs_read(fd, stat.size, 0)
	vim.loop.fs_close(fd)

	if err then
		print("Error: could not read file: " .. err)
		return nil, errcode
	end

	local ok, json = pcall(vim.fn.json_decode, content)
	if not ok then
		print("Error: could not decode json: " .. json)
		return nil, json
	end

	return json, nil
end

return M
