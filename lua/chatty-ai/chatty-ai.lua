local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')

function M.setup(opts)
  config.from_user_opts(opts)
  log.info('configured')
end

function M.complete()
end

return M
