local validation = require("validation")

local M = {}

local config = {}

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

--- @param command_args string[] The rsync arguments to run
local function run_rsync(command_args)
  local job_id
  local output_chunks = {}
  local password_sent = false

  local function on_stdout(_, data, _)
    for _, line in ipairs(data) do
      local clean = line:gsub("\r", "")
      if not password_sent and clean:lower():find("password:") then
        password_sent = true
        vim.schedule(function()
          local password = vim.fn.inputsecret("SSH password: ")
          vim.fn.chansend(job_id, password .. "\n")
          password_sent = false
        end)
      elseif clean ~= "" then
        table.insert(output_chunks, clean)
      end
    end
  end

  local function on_exit(_, code, _)
    vim.schedule(function()
      if code ~= 0 then
        vim.api.nvim_err_writeln("rsync failed with code: " .. code)
      else
        vim.api.nvim_echo({
          { "rsync completed successfully:\n" .. table.concat(output_chunks, "\n"), "Normal" },
        }, true, {})
      end
    end)
  end

  local cmd = vim.list_extend({ "rsync" }, command_args)
  job_id = vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = on_stdout,
    on_exit = on_exit,
  })

  if job_id <= 0 then
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

return M
