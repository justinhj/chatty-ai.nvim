local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')
local C = require('chatty-ai.completion')

function M.setup(opts)
  config.from_user_opts(opts)
  local result, err = config.validate()
  if not result then
    log.error('Failed to validate config: ' .. err)
    return
  end
end

function M.complete(prompt, completion_config)
  return C.completion_job(prompt, completion_config)
end

return M
