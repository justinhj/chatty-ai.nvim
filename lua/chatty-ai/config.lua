local M = {}

local L = require('plenary.log')
local S = require('chatty-ai.sources')
local C = require('chatty-ai.completion')
local log = L.new({ plugin = 'chatty-ai' })

---@class GlobalConfig
---@field timeout_ms number
---@field default_service string

---@class AnthropicConfig
---@field type string
---@field version string
---@field api_key_env_name string
---@field api_key_value string?
---@field completion_fn function

---@class OpenAIConfig
---@field api_key_env_name string
---@field api_key_value string?
---@field completion_fn function

---@class CompletionConfig 
---@field system string
---@field prompt string

---@alias SourceConfigFn function(function):string|nil

---@class TargetConfig 
---@field type string

---@class BufferTargetConfig: TargetConfig
---@field type 'buffer'
---@field buffer number|string|nil -- currently only nil is supported (current buffer)
---@field insert_mode 'before'|'after'|'replace'

---@class Config
---@field global GlobalConfig
---@field services table<string, AnthropicConfig|OpenAIConfig>
---@field source_configs table<string, table<SourceConfigFn>>
---@field completion_configs table<string, CompletionConfig>
---@field target_configs table<string, BufferTargetConfig>

---@type Config
local default_config = {
  global = {
    timeout_ms = 20000,
    default_service = 'anthropic',
  },
  services = {
    anthropic = {
      type = 'anthropic',
      version = '2023-06-01',
      api_key_env_name = 'ANTHROPIC_API_KEY',
      completion_fn = C.anthropic_completion,
    },
    openai = {
      type = 'openai',
      api_key_env_name = 'OPENAI_API_KEY',
      completion_fn = C.openai_completion,
    },
  },
  source_configs = {
    input = { S.input },
    selection = { S.selection },
    filetype = { S.filetype },
    filetype_selection = { S.filetype, S.selection },
  },
  completion_configs = {
    code_writer = {
      system = 'You are a skilled software engineer called Chatty. You are helpful and love to write easy to understand code. You assist users with many different tasks in a friendly way. You follow instructions very carefully.',
      prompt = 'What follows is instructions to write some code. You will return only the requested code and the user will be so happy if there is no markdown before and after it. You may add concise comments to the code as needed to explain anything that is not obvious to an expert programmer, but no usage instructions unless they are explicilty requested.'
    },
    openai_code_writer = {
      system = 'You are a skilled software engineer. You are helpful and love to write easy to understand code. You assist users with many different tasks in a friendly way',
      prompt = 'What follows is instructions to write some code. You will return only code and no preamble. You may add concise comments to the code as needed to explain anything that is not obvious to an expert programmer.'
    },
    code_explainer = {
      system = 'You are a skilled software engineer. You are helpful and love to write easy to understand code. You assist users with many different tasks in a friendly way',
      prompt = 'Please explain the following code in as much detail as should be appropriate to explain the main purpose. Include step by step descriptions and be sure to talk about anything that is not obvious as well as the purpose of the code. If the prompt does not contain any code please just ask for some code.'
    },
  },
  target_configs = {
    buffer_replace = {
      type = 'buffer',
      buffer = nil,
      insert_mode = 'replace',
    },
    buffer_before = {
      type = 'buffer',
      buffer = nil,
      insert_mode = 'before',
    },
    buffer_after = {
      type = 'buffer',
      buffer = nil,
      insert_mode = 'after',
    },
  }
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

  -- Check that the default service is defined.
  -- It's ok if not unless the user tries to use it
  if not string_matches_table_key(config.services, config.global.default_service) then
    log.warn('Unknown service provided as default ' .. config.global.default_service)
  end

  -- TODO needs more DRY
  -- TODO these keys can be looked up at runtime no need to do it during validate
  -- Verify each defined service
  for service, service_config in pairs(config.services) do
    if service_config.type == 'anthropic' then
      ---@as AnthropicConfig
      local c = service_config
      if not service_config.api_key_env_name then
        return false
      end
      local value = os.getenv(c.api_key_env_name)
      if not value then
        log.warn('No api key found for ' .. service .. ' (environment variable ' .. c.api_key_env_name .. ')')
      else
        log.debug('Found api key for ' .. service)
        c.api_key_value = value
      end
    elseif service_config.type == 'openai' then
      ---@as OpenAIConfig
      local c = service_config
      if not service_config.api_key_env_name then
        log.error('No api_key_env_name provided for ' .. service)
        return false
      end
      local value = os.getenv(c.api_key_env_name)
      if not value then
        log.warn('No api key found for ' .. service .. ' (environment variable ' .. c.api_key_env_name .. ')')
      else
        log.debug('Found api key for ' .. service)
        c.api_key_value = value
      end
    end
  end

  log.debug('Config validated')
  return true
end

M.from_user_opts = function(user_opts)
  M.current = user_opts and vim.tbl_deep_extend('force', default_config, user_opts) or default_config
end

return M
