local M = {}

---@class SourceConfig
---@field name string
---@field get_completion_params function 

-- Exposes the public API

local chatty_ai = require('chatty-ai.chatty-ai')
local services = require('chatty-ai.services')

M.complete = chatty_ai.complete
M.setup = chatty_ai.setup
M.list_services = services.list_services
M.register_service = services.register_service

return M
