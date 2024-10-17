local M = {}

-- Exposes the public API

local chatty_ai = require('chatty-ai.chatty-ai')
local services = require('chatty-ai.services')

M.setup = chatty_ai.setup
M.complete = chatty_ai.complete

M.status = chatty_ai.get_status

M.list_services = services.list_services
M.register_service = services.register_service

return M
