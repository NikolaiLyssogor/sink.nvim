local validation = require("validation")

local M = {}

local config = {}

local function stream_stdout(stdout, stdout_chunks)
  vim.uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      table.insert(stdout_chunks, data)
    end
  end)
end

local function handle_rsync_exit(code, signal, stdout_chunks)
  vim.schedule(function()
    if code ~= 0 then
      vim.api.nvim_err_writeln("rsync failed with code: " .. code)
    else
      vim.api.nvim_echo({
        { "rsync completed successfully:\n" .. table.concat(stdout_chunks, ""), "Normal" },
      }, true, {})
    end
  end)
end

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

--- @param command_args string[] The rsync arguments to run
local function run_rsync(command_args)
  local handle
  local stdin = vim.uv.new_pipe()
  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()
  local stdout_chunks = {}

  handle, _ = vim.uv.spawn("rsync", {
    args = command_args,
    stdio = { stdin, stdout, stderr },
  }, function(code, signal)
    handle_rsync_exit(code, signal, stdout_chunks)
  end)

  stream_stdout(stdout, stdout_chunks)

  if not handle then
    vim.api.nvim_err_writeln("Failed to start rsync process")
  end
end

--- @param use_default boolean Whether to use the default command or show a picker
function M.sink(use_default)
  local local_config = validation.load_local_config(use_default)
  if local_config == nil then
    return
  end

  if use_default then
    -- Find and run the default command
    for _, cmd in ipairs(local_config.commands) do
      if cmd.default == true then
        run_rsync(cmd.command)
        return
      end
    end
  else
    -- Show a picker for the user to select a command
    local items = {}
    for _, cmd in ipairs(local_config.commands) do
      table.insert(items, cmd.description)
    end

    vim.ui.select(items, {
      prompt = "Select a command to run:",
    }, function(choice, idx)
      if choice and idx then
        run_rsync(local_config.commands[idx].command)
      end
    end)
  end
end

vim.api.nvim_create_user_command("Sink", function(opts)
  local arg = opts.args

  -- Parse "default=true" or "default=false"
  local use_default
  if arg == "default=true" then
    use_default = true
  elseif arg == "default=false" then
    use_default = false
  else
    vim.api.nvim_err_writeln("Sink command requires 'default=true' or 'default=false' as argument")
    return
  end

  M.sink(use_default)
end, { nargs = 1 })

return M
