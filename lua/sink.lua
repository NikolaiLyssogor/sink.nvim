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

--- @param op "push" | "pull" The operation to be performed
function M.rsync(op)
  local local_config = validation.load_local_config(op)
  if local_config == nil then
    return
  end

  local handle
  local stdin = vim.uv.new_pipe()
  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()
  local stdout_chunks = {}

  handle, _ = vim.uv.spawn("rsync", {
    args = local_config[op],
    stdio = { stdin, stdout, stderr },
  }, function(code, signal)
    handle_rsync_exit(code, signal, stdout_chunks)
  end)

  stream_stdout(stdout, stdout_chunks)

  if not handle then
    vim.api.nvim_err_writeln("Failed to start rsync process")
  end
end

vim.api.nvim_create_user_command("SinkPush", function(_)
  M.rsync("push")
end, {})
vim.api.nvim_create_user_command("SinkPull", function(_)
  M.rsync("pull")
end, {})

return M
