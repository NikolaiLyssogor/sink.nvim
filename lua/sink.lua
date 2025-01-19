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

function M.setup(opts)
	config = vim.tbl_extend("force", config, opts or {})
end

function M.push()
  --TODO: only push if cwd == source?
	local config1 = config[1]

	if not in_dir(config1.source) then
		vim.api.nvim_echo(
			{
				{
					"Warning: The current working directory is not within the directory to be synced. Aborting.",
					"WarningMsg",
				},
			},
			true,
			{}
		)
		return
	end

	local output = vim.fn.system({
		"rsync",
		"-avz",
		"--delete",
		"--exclude-from",
		config1.exclude,
		config1.source,
		config1.dest,
	})

	if vim.v.shell_error ~= 0 then
		vim.api.nvim_err_writeln("rsync failed: " .. output)
	else
		print(output)
	end
end

vim.api.nvim_create_user_command("SinkPush", M.push, {})

return M
