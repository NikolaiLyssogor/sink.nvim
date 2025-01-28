local M = {}

--- @type table<{source: string, dest: string, exclude: string}>[]
local config = {}

--- Checks if the `cwd` is in `dir`.
---@param dir string
---@return boolean
local function in_dir(dir)
	local cwd = vim.loop.cwd()

	-- Ensure both paths end without a trailing slash for accurate comparison
	if dir:sub(-1) == "/" then
		dir = dir:sub(1, -2)
	end
	if cwd:sub(-1) == "/" then
		cwd = cwd:sub(1, -2)
	end

	-- Check if the cwd starts with the specified directory path
	if cwd:sub(1, #dir) ~= dir then
		return false
	else
		return true
	end
end

---@param source_dir string
---@return boolean
local function warn_if_not_in_source_dir(source_dir)
	if not in_dir(source_dir) then
		vim.api.nvim_echo({
			{
				"Warning: The current working directory is not within the directory to be synced. Aborting.",
				"WarningMsg",
			},
		}, true, {})
		return false
	end

	return true
end

local function handle_exit(code, signal)
	if code ~= 0 then
		vim.api.nvim_err_writeln("rsync failed with code: " .. code)
	else
		print("rsync completed successfully")
	end
end

function M.setup(opts)
	config = vim.tbl_extend("force", config, opts or {})
end

function M.push()
	--TODO: only push if cwd == source?
	local config1 = config[1]

	if not warn_if_not_in_source_dir(config1.source) then
		return
	end

	local handle, pid
	local stdout = vim.uv.new_pipe(false)
	local output = {}

	-- run rsync to push to the remote
	handle, pid = vim.uv.spawn("rsync", {
		args = {
			"-avz",
			"--delete",
			"--exclude-from",
			config1.exclude,
			config1.source,
			config1.dest,
		},
		stdio = { nil, stdout, nil },
	}, function(code, signal)
		print("exit code", code)
		print("exit signal", signal)
	end)

	if not handle then
		vim.api.nvim_err_writeln("Failed to start rsync process")
	end
end

function M.pull()
	local config1 = config[1]

	if not warn_if_not_in_source_dir(config1.source) then
		return
	end

	local handle, pid
	handle, pid = vim.uv.spawn("rsync", {
		args = {
			"-avz",
			"--exclude-from",
			config1.exclude,
			config1.dest,
			config1.source,
		},
		stdio = { nil, nil, nil },
	}, function(code, signal)
		print("exit code", code)
		print("exit signal", signal)
	end)

	if not handle then
		vim.api.nvim_err_writeln("Failed to start rsync process")
	end
end

vim.api.nvim_create_user_command("SinkPush", M.push, {})
vim.api.nvim_create_user_command("SinkPull", M.pull, {})

return M
