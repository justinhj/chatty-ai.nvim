local M = {}

---@class SourceConfig
---@field name string
---@field get_completion_params function 

---@class ChattyConfig
---@field global GlobalConfig
---@field services table<string>
---@field source_configs table<string, table<SourceConfigFn>>
---@field completion_configs table<string, CompletionConfig>
---@field target_configs table<string, BufferTargetConfig>

-- Exposes the public API

local chatty_ai = require('chatty-ai.chatty-ai')
local services = require('chatty-ai.services')

M.setup = chatty_ai.setup
M.complete = chatty_ai.complete

M.status = chatty_ai.get_status

M.list_services = services.list_services
M.register_service = services.register_service

return M
