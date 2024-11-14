local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')
local completion = require('chatty-ai.completion')
local services = require('chatty-ai.services')
local util = require('chatty-ai.util')

function M.setup_user_commands()

  -- Enable the user to bring the chat context into view
  -- error if context name not set
  vim.api.nvim_create_user_command('ChattyContextShow',
    function ()
      require('chatty-ai.context').show_context()
    end
    ,{nargs = 0})

  vim.api.nvim_create_user_command('ChattyContextName',
    function (opts)
      require('chatty-ai.context').set_name(opts.args)
    end
    ,{nargs = 1})

  vim.api.nvim_create_user_command('ChattyContextClear',
    function ()
      require('chatty-ai.context').clear_context({'system'})
    end
    ,{nargs = 0})

  vim.api.nvim_create_user_command('ChattyContextClearAll',
    function ()
      require('chatty-ai.context').clear_context()
    end
    ,{nargs = 0})

  vim.api.nvim_create_user_command('ChattyContextSetSystemPrompt',
    function (opts)
      local system_prompt = vim.g.chatty_ai_config.system_prompts[opts.args] or opts.args
      require('chatty-ai.context').set_system_prompt(system_prompt)
    end
    ,{nargs = 1,
      complete = function(ArgLead, CmdLine, CursorPos)
        return util.get_table_keys(vim.g.chatty_ai_config.system_prompts)
      end,})

  vim.api.nvim_create_user_command('ChattyContextAddPrompt',
    function (opts)
      local prompt = vim.g.chatty_ai_config.prompts[opts.args] or opts.args
      require('chatty-ai.context').set_prompt(prompt)
    end
    ,{nargs = 1,
      complete = function(ArgLead, CmdLine, CursorPos)
        return util.get_table_keys(vim.g.chatty_ai_config.prompts)
      end,})

  vim.api.nvim_create_user_command('ChattyContextAddSource',
    function (opts)
      if vim.g.chatty_ai_config.source_configs[opts.args] ~= nil then
        require('chatty-ai.context').add_sources(opts.args)
      else
        error(opts.args .. ' is not found in source_configs')
      end
    end
    ,{nargs = 1,
      complete = function(ArgLead, CmdLine, CursorPos)
        -- vim.print(ArgLead .. ' - ' .. CmdLine .. ' - ' .. tostring(CursorPos))
        return util.get_table_keys(vim.g.chatty_ai_config.source_configs)
      end,})
end

-- For the status bar
function M.get_status()
  local last_input_tokens = vim.g.chatty_ai_last_input_tokens or 0
  local last_output_tokens = vim.g.chatty_ai_last_output_tokens or 0
  return ' >' .. tostring(last_input_tokens) .. ' <' .. tostring(last_output_tokens)
end

function M.setup(opts)
  opts = opts or {}
  config.from_user_opts(opts)

  if vim.g.chatty_ai_is_setup == nil then
    vim.g.chatty_ai_is_setup = true
  end
end

function M.complete(service_name, target_config_name, should_stream)
  if vim.g.chatty_ai_is_setup ~= true then
    -- TODO this should happen at a higher level perhaps
    log.error('Setup needs to be called before complete works.')
    return
  end

  local service = services.get_service(service_name)
  if service == nil then
    log.error('Service ' .. service_name .. ' is not registered.')
    return
  end

  local target_config = vim.g.chatty_ai_config.target_configs[target_config_name]
  if target_config == nil then
    log.error('Target config not found for ' .. target_config_name)
    return
  end

  return completion.completion_job(service, target_config, should_stream)
end

return M
