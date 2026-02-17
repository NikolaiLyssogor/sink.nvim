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

  require("sink").sink(use_default)
end, { nargs = 1 })
