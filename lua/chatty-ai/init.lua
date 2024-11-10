local M = {}

-- Exposes the public API

local core = require('chatty-ai.core')
local services = require('chatty-ai.services')

M.setup = core.setup
M.complete = core.complete

M.status = core.get_status

M.list_services = services.list_services
M.register_service = services.register_service

return M
