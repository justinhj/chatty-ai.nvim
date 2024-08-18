local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')
local completion = require('chatty-ai.completion')

function M.setup(opts)
  config.from_user_opts(opts)
  local result, err = config.validate()
  if not result then
    log.error('Failed to validate config: ' .. err)
    return
  end
end

local function config_names_to_configs(service_config_name, source_config_name, completion_config_name, target_config_name)
  local service_config = config.current.services[service_config_name]
  if service_config == nil then
    log.error('service config not found for ' .. service_config_name)
    return
  end

  if service_config_name == nil then
    service_config_name = config.current.global.default_service
  end

  local source_config = config.current.source_configs[source_config_name]
  if source_config == nil then
    log.error('source config not found: ' .. source_config_name)
    return
  end

  local completion_config = config.current.completion_configs[completion_config_name]
  if completion_config == nil then
    log.error('completion config not found for ' .. completion_config_name)
    return
  end

  local target_config = config.current.target_configs[target_config_name]
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

  return completion.completion_job(config.current.global, service_config, source_config, completion_config, target_config, should_stream)
end

return M
