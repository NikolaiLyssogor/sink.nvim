local M = {}

--- @class RsyncArgs
--- @field args string[] # array of arguments for rsync

--- @class ConfigEntry
--- @field push RsyncArgs
--- @field pull RsyncArgs

--- @class SinkConfig
--- @field paths table<string, ConfigEntry>

--- @type SinkConfig
local config = {}

--- @param t table
--- @return number
local function table_len(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end

  return count
end

---@param warning string
local function echo_warning(warning)
  vim.api.nvim_echo({ { warning, "WarningMsg" } }, true, {})
end

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

--- @param op "push" | "pull" The operation to perform
--- @return boolean, string
local function health(op)
  -- No paths configured for rsync
  if config.paths == nil or table_len(config.paths) == 0 then
    return false, "No paths are configured for sink.nvim."
  end

  -- No paths configured for cwd
  local cwd = vim.loop.cwd()
  if config.paths[cwd] == nil then
    return false, "sink.nvim: No paths configured for " .. cwd
  end

  -- Make sure specified op is configured for this directory
  if config.paths[cwd][op] == nil then
    return false, "sink.nvim: Command '" .. op .. "' not configured for " .. cwd
  end

  return true, ""
end

--- @param op "push" | "pull" The operation to be performed
function M.rsync(op)
  local health_status, health_msg = health(op)
  if not health_status then
    echo_warning(health_msg)
    return
  end

  local handle, pid
  local stdin = vim.uv.new_pipe()
  local stdout = vim.uv.new_pipe()
  local stderr = vim.uv.new_pipe()
  local stdout_chunks = {}

  local cwd = vim.loop.cwd()
  local args = config.paths[cwd][op].args

  handle, pid = vim.uv.spawn("rsync", {
    args = args,
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
