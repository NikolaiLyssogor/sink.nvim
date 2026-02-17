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
    echo_error("No .sink.json file found in cwd: " .. cwd)
    return nil
  end

  local raw_config = f:read("*a")
  f:close()
  return raw_config
end

---@param command_config table
---@param index number
---@return boolean
local function validate_command(command_config, index)
  -- Check for description
  if not command_config.description or type(command_config.description) ~= "string" then
    echo_error("sink.nvim: Command #" .. index .. " must have a 'description' field (string).")
    return false
  end

  -- Check for command
  if not command_config.command then
    echo_error("sink.nvim: Command #" .. index .. " must have a 'command' field.")
    return false
  end

  local args = command_config.command
  if type(args) ~= "table" then
    echo_error("sink.nvim: 'command' in command #" .. index .. " must be an array.")
    return false
  end

  local n_args = #args
  if n_args == 0 then
    echo_error("sink.nvim: 'command' in command #" .. index .. " cannot be empty.")
    return false
  end

  for k, v in pairs(args) do
    if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > n_args then
      echo_error("sink.nvim: Command arguments must all be strings in command #" .. index .. ".")
      return false
    end

    if type(v) ~= "string" then
      echo_error("sink.nvim: Command arguments must all be strings in command #" .. index .. ".")
      return false
    end
  end

  -- 'rsync' should not be the first element in the table
  if args[1] == "rsync" then
    echo_error(
      "sink.nvim: 'rsync' should not be one of the arguments in command #" .. index .. ". Provide only the arguments to rsync."
    )
    return false
  end

  return true
end

---@param config table
---@param require_default boolean
---@return boolean
local function validate_sink_json(config, require_default)
  if not config.commands then
    echo_error("sink.nvim: .sink.json must have a 'commands' array.")
    return false
  end

  if type(config.commands) ~= "table" then
    echo_error("sink.nvim: 'commands' must be an array.")
    return false
  end

  if #config.commands == 0 then
    echo_error("sink.nvim: At least one command must be specified in 'commands'.")
    return false
  end

  -- Validate each command
  for i, cmd in ipairs(config.commands) do
    if not validate_command(cmd, i) then
      return false
    end
  end

  -- If require_default is true, check for exactly one default
  if require_default then
    local default_count = 0
    for _, cmd in ipairs(config.commands) do
      if cmd.default == true then
        default_count = default_count + 1
      end
    end

    if default_count == 0 then
      echo_error("sink.nvim: No default command found. One command must have 'default: true'.")
      return false
    end

    if default_count > 1 then
      echo_error("sink.nvim: Multiple default commands found. Only one command can have 'default: true'.")
      return false
    end
  end

  return true
end

---@param require_default boolean
---@return table|nil
function M.load_local_config(require_default)
  local raw_config = read_config()
  if raw_config == nil then
    return nil
  end

  local ok, config = pcall(vim.json.decode, raw_config)
  if not ok then
    echo_error("Error: Unable to decode .sink.json.")
    return nil
  end

  if not validate_sink_json(config, require_default) then
    return nil
  end

  return config
end

return M
