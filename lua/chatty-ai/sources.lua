local M = {}

local U = require('chatty-ai.util')
local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })

-- Sources provide ways to get the prompt to send to chatty
-- TODO does it need to configure?
function M.input(callback)
  vim.ui.input({prompt = 'Enter a prompt: '}, callback)
end

function M.selection(callback)
  log.debug('getting visual selection')
  local lines, _ = U.get_visual_selection()
  log.debug('got visual selection: ' .. vim.inspect(lines))
  callback(lines)
end

function execute_sources_internal(source_configs, aggregate_prompt, callback)
  log.debug('length of source configs is ' .. #source_configs)
  aggregate_prompt = aggregate_prompt or ""
  if #source_configs == 0 then
    callback(aggregate_prompt)
  else
    local source = table.remove(source_configs, 1)
    local source_callback = function(input)
      input = input or ""
      execute_sources_internal(source_configs, aggregate_prompt .. input, callback)
    end
    source(source_callback)
  end
end

-- Execute sources takes a list of sources and executes them, appending all the 
-- prompts together before calling the callback

---@param source_configs table<SourceConfigFn>
---@param aggregate_prompt string|nil
function M.execute_sources(source_configs, aggregate_prompt, callback)
  local source_configs_copy = U.shallowcopy(source_configs)
  execute_sources_internal(source_configs, aggregate_prompt, callback)
end

return M
