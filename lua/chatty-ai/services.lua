local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })

local M = {}

-- Create and track service instances
---@class CompletionServiceConfig
---@field public name string
---@field public stream_error_cb function
---@field public stream_complete_cb function
---@field public error_cb function
---@field public complete_cb function
---@field public stream_cb function
---@field public configure_call function

-- stream_error_cb
--   called when a streaming response throws an error
-- stream_cb
--   called when the streaming response has new data
-- stream_complete_cb
--   called when a streaming response is completed

-- complete_cb
--   called when non-streaming response is completed

M.services = {}

---@param name string
M.new = function(name, s)
  local self = setmetatable({}, { __index = M })
  self.name = name
  self.service = s
  return self
end

---@param name string
---@param s CompletionServiceConfig
M.register_service = function(name, s)
  local service = M.new(name, s)
  M.services[name] = service
end

---@param name string
M.unregister_service = function(name)
  M.services[name] = nil
end

---@param name string
M.get_service = function(name)
  local s = M.services[name]
  if s ~= nil then 
    return s.service
  else
    return nil
  end
end

M.list_services = function()
  local texts = { { "Services\n", 'Title' } }
  for name,service in pairs(M.services) do
    table.insert(texts, { name .. '\n', 'Normal' })
  end
  vim.api.nvim_echo(texts, false, {})
end

return M
