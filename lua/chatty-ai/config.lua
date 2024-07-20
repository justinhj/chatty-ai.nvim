local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })

---@class GlobalConfig
---@field timeout_ms number
---@field default_service string

---@class AnthropicConfig
---@field type string
---@field version string
---@field api_key_env_name string
---@field api_key_value string?

---@class OpenAIConfig
---@field version string
---@field api_key_env_name string
---@field api_key_value string?

---@class CompletionConfig 
---@field system string
---@field prompt string
---@field service string?

---@class Config
---@field global GlobalConfig
---@field services table<string, AnthropicConfig|OpenAIConfig>
---@field completion_configs table<string, CompletionConfig>

---@type Config
local default_config = {
  global = {
    timeout_ms = 5000,
    default_service = 'anthropic',
  },
  services = {
    anthropic = {
      type = 'anthropic',
      version = '2023-06-01',
      api_key_env_name = 'ANTHROPIC_API_KEY',
    },
  },
  completion_configs = {
    code_writer = {
      system = 'You are a skilled software engineer. You are helpful and love to write easy to understand code. You assist users with many different tasks in a friendly way',
      prompt = 'What follows is instructions to write some code. You will return only code and no preamble. You may concise comments to the code as needed to explain anything that is not obvious',
      service = 'anthropic',
    },
  },
}

M.current = default_config

-- TODO util
local function string_matches_table_key(tbl, str)
    for key, _ in pairs(tbl) do
        if str == key then
            return true
        end
    end
    return false
end

-- Validate the passed in config, or the current config
-- @param config Config
M.validate = function(config)
  if not config then
    config = M.current
  end

  -- Check that the default service is defined
  if not string_matches_table_key(config.services, config.global.default_service) then
    return false, 'Unknown service provided as default ' .. config.global.default_service
  end

  -- Verify each defined service
  for service, service_config in pairs(config.services) do
    if service_config.type == 'anthropic' then
      ---@as AnthropicConfig
      local c = service_config
      if not service_config.api_key_env_name then
        return false, 'No api_key_env_name provided for ' .. service
      end
      local value = os.getenv(c.api_key_env_name)
      if not value then
        return false, 'No api key found for ' .. service .. ' (environment variable ' .. c.api_key_env_name .. ')'
      else
        log.debug('Found api key')
        c.api_key_value = value
      end
      elseif service_config.type == 'openai' then
        ---@as OpenAIConfig
        -- local c = service_config
        log.debug('OpenAI service not implemented yet')
      end
  end

  log.debug('Config validated')
  return true
end

M.from_user_opts = function(user_opts)
  M.current = user_opts and vim.tbl_deep_extend('force', default_config, user_opts) or default_config
end

return M
