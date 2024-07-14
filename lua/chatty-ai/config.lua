local M = {}

local default_config = {
  global = {
    request_timeout = 5000,
  },
  anthropic = {
    version = '2023-06-01',
    api_key_env_name = 'ANTHROPIC API KEY',
  },
}

M.current = default_config

M.from_user_opts = function(user_opts)
  M.current = user_opts and vim.tbl_deep_extend('force', default_config, user_opts) or default_config
end

return M
