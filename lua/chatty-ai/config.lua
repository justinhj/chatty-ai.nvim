local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })

---@class CompletionConfig
---@field system string
---@field prompt string
---@field service string|nil

---@class GlobalConfig
---@field timeout_ms number
---@field service string

---@class AnthropicConfig
---@field version string
---@field api_key_env_name string
---@field api_key_value string?

---@class Config
---@field global GlobalConfig
---@field anthropic AnthropicConfig

---@type Config
local default_config = {
  global = {
    timeout_ms = 5000,
    service = 'anthropic',
  },
  anthropic = {
    version = '2023-06-01',
    api_key_env_name = 'ANTHROPIC_API_KEY',
  },
}

M.known_services = {'anthropic'}

M.current = default_config

-- Validate the passed in config, or the current config
-- @param config Config
M.validate = function(config)
  if not config then
    config = M.current
  end

  if not vim.tbl_contains(M.known_services, config.global.service) then
    return false, 'Unknown service provided'
  end

  if not config[config.global.service].api_key_env_name then
    return false, 'No api_key_env_name provided' .. config.global.service
  else
    local value = os.getenv(config[config.global.service].api_key_env_name)
    if not value then
      return false, 'No api key found for ' .. config.global.service .. ' (environment variable ' .. config[config.global.service].api_key_env_name .. ')'
    else
      log.debug('Found api key')
      config[config.global.service].api_key_value = value
    end
  end
  log.debug('Config validated')
  return true
end

M.from_user_opts = function(user_opts)
  M.current = user_opts and vim.tbl_deep_extend('force', default_config, user_opts) or default_config
end

return M
