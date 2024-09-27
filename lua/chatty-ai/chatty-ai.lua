local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')
local completion = require('chatty-ai.completion')

local function setup_user_commands()

  -- Enable the user to bring the chat history into view
  -- error if history name not set
  vim.api.nvim_create_user_command('ChattyHistoryShow',
    function ()
      require('chatty-ai.history').show_history()
    end
    ,{nargs = 0})

  vim.api.nvim_create_user_command('ChattyHistoryClear',
    function ()
      require('chatty-ai.history').clear_history()
    end
    ,{nargs = 0})

  -- TODO user command to change the history file name
  -- so they can swap between different activities
end

-- TODO return the input and output tokens of the last request, stored in global state
function M.get_status()
  local last_input_tokens = vim.g.last_input_tokens or 0
  local last_output_tokens = vim.g.last_output_tokens or 0
  return ' >' .. tostring(last_input_tokens) .. ' <' .. tostring(last_output_tokens)
end

function M.setup(opts)
  opts = opts or {}
  config.from_user_opts(opts)
  local result, err = config.validate()
  if not result then
    log.error('Failed to validate config: ' .. err)
    return
  end

  setup_user_commands()
end

local function config_names_to_configs(service_config_name, source_config_name, completion_config_name, target_config_name)
  local service_config = vim.g.chatty_ai_config.services[service_config_name]
  if service_config == nil then
    log.error('service config not found for ' .. service_config_name)
    return
  end

  if service_config_name == nil then
    service_config_name = vim.g.chatty_ai_config.global.default_service
  end

  local source_config = vim.g.chatty_ai_config.source_configs[source_config_name]
  if source_config == nil then
    log.error('source config not found: ' .. source_config_name)
    return
  end

  local completion_config = vim.g.chatty_ai_config.completion_configs[completion_config_name]
  if completion_config == nil then
    log.error('completion config not found for ' .. completion_config_name)
    return
  end

  local target_config = vim.g.chatty_ai_config.target_configs[target_config_name]
  if target_config == nil then
    log.error('target config not found for ' .. target_config_name)
    return
  end

  return source_config, completion_config, target_config, service_config
end

function M.complete(source_config_name, completion_config_name, target_config_name, should_stream, service_config_name)
  local source_config, completion_config, target_config, service_config =
    config_names_to_configs(service_config_name, source_config_name, completion_config_name, target_config_name)

  if source_config == nil or completion_config == nil or target_config == nil or service_config == nil then
    log.error('Failed to get configs'.. source_config_name .. completion_config_name .. target_config_name .. service_config_name)
    return
  end

  return completion.completion_job(vim.g.chatty_ai_config.global, service_config, source_config, completion_config, target_config, should_stream)
end

return M
