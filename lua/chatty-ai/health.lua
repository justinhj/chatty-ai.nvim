local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local error = vim.health.error or vim.health.report_error

local C = require('chatty-ai/config')

function M.check()
  start('Checking api keys')
  if C.anthropic.api_key_env_name and os.getenv(C.api_key_env_name) then
    ok('Anthropic API key found')
  else
    error('No Anthropic API key found')
  end
end

return M
