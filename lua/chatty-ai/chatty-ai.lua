local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')
local completion = require('chatty-ai.completion')
local services = require('chatty-ai.services')
local util = require('chatty-ai.util')

-- TODO maybe rename core

function M.setup_user_commands()

  -- Enable the user to bring the chat context into view
  -- error if context name not set
  vim.api.nvim_create_user_command('ChattyContextShow',
    function ()
      require('chatty-ai.context').show_context()
    end
    ,{nargs = 0})

  vim.api.nvim_create_user_command('ChattyContextClear',
    function ()
      require('chatty-ai.context').clear_context()
    end
    ,{nargs = 0})

  -- TODO user command to change the context file name
  -- so they can swap between different activities
end

-- TODO return the input and output tokens of the last request, stored in global state
function M.get_status()
  local last_input_tokens = vim.g.chatty_ai_last_input_tokens or 0
  local last_output_tokens = vim.g.chatty_ai_last_output_tokens or 0
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

  if vim.g.chatty_ai_is_setup == nil then
    vim.g.chatty_ai_is_setup = true
  end
end

local function config_names_to_configs(source_config_name, completion_config_name, target_config_name)
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

  return source_config, completion_config, target_config
end

function M.complete(service_name, source_config_name, completion_config_name, target_config_name, should_stream)
  if vim.g.chatty_ai_is_setup ~= true then
    -- TODO this should happen at a higher level perhaps
    log.error('Setup needs to be called before complete works.')
    return
  end

  local found = util.find_string_in_table(vim.g.chatty_ai_config.services, service_name)
  if found == nil then
    log.error(service_name .. ' is not found in config.')
    return
  end

  local service = services.get_service(service_name)
  if service == nil then
    log.error('Service ' .. service_name .. ' is not registered.')
    return
  end

  local source_config, completion_config, target_config =
    config_names_to_configs(source_config_name, completion_config_name, target_config_name)

  if source_config == nil or completion_config == nil or target_config == nil then
    log.error('Failed to get configs: '.. source_config_name .. completion_config_name .. target_config_name)
    return
  end

  return completion.completion_job(service, source_config, completion_config, target_config, should_stream)
end

return M
