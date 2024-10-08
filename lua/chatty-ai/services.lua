-- Create and track service instances

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })

local M = {}

M.services = {}

M.new = function(name, s)
  local self = setmetatable({}, { __index = M })
  self.name = name
  self.source = s
  return self
end

M.register_service = function(name, s)
  local service = M.new(name, s)
  M.services[name] = service
end

M.unregister_service = function(name)
  M.sources[name] = nil
end

M.list_services = function()
  local texts = { { "Services", 'Title' } }
  for i,s in ipairs(M.services) do
    table.insert(texts, { i, 'Normal' })
  end
  vim.api.nvim_echo(texts, false, {})
end

return M
