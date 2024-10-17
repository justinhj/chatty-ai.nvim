-- Create and track service instances

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })

local M = {}

M.services = {}

---@param name string
M.new = function(name, s)
  local self = setmetatable({}, { __index = M })
  self.name = name
  self.source = s
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
  M.sources[name] = nil
end

---@param name string
M.get_service = function(name)
  return M.services[name]
end

M.list_services = function()
  local texts = { { "Services\n", 'Title' } }
  for name,source in pairs(M.services) do
    table.insert(texts, { name .. '\n', 'Normal' })
  end
  vim.api.nvim_echo(texts, false, {})
end

return M
