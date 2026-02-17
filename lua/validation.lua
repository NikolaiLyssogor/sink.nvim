local M = {}

---@param message string
local function echo_error(message)
  vim.api.nvim_echo({ { message, "ErrorMsg" } }, true, {})
end

local function read_config()
  local cwd = vim.loop.cwd()
  local config_filepath = cwd .. "/.sink.json"

  local f = io.open(config_filepath, "rb")
  if f == nil then
    echo_error("No .sink.toml file found in cwd: " .. cwd)
    return nil
  end

  local raw_config = f:read("*a")
  f:close()
  return raw_config
end

---@param config table
---@param op "push" | "pull"
---@return boolean
local function validate_sink_json(config, op)
  if op == "push" and not config.push then
    echo_error("sink.nvim: To run SinkPush, you must have 'push' configured in .sink.json.")
    return false
  end
  if op == "pull" and not config.pull then
    echo_error("sink.nvim: To run SinkPull, you must have 'pull' configured in .sink.json.")
    return false
  end

  -- Make sure `push` and `pull` entries are a flat list of strings
  local args = config[op]

  if type(args) ~= "table" then
    echo_error("sink.nvim: '" .. op .. "' key in .sink.json is not an array.")
    return false
  end

  local n_args = #args
  for k, v in pairs(args) do
    if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > n_args then
      echo_error("sink.nvim: rsync arguments must all be strings.")
      return false
    end

    if type(v) ~= "string" then
      echo_error("sink.nvim: rsync arguments must all be strings.")
      return false
    end
  end

  -- 'rsync' should not be the first element in the table
  if args[1] == "rsync" then
    echo_error(
    "sink.nvim: 'rsync' should not be one of the arguments in .sink.json. Provide only the arguments to rsync.")
    return false
  end

  return true
end

---@param op "push" | "pull"
---@return table<string, string[]>|nil
function M.load_local_config(op)
  local raw_config = read_config()
  if raw_config == nil then
    return nil
  end

  local ok, config = pcall(vim.json.decode, raw_config)
  if not ok then
    echo_error("Error: Unable to decode .sink.json.")
    return nil
  end

  if not validate_sink_json(config, op) then
    return nil
  end

  return config
end

return M
