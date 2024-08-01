local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })

-- Sources provide ways to get the prompt to send to chatty
-- TODO change the name to input
-- TODO how to configure
function M.prompt_ui(callback)
  vim.ui.input({prompt = 'Enter a prompt: '}, callback)
end

-- Execute sources takes a list of sources and executes them, appending all the 
-- prompts together before calling the callback

---@param source_configs table<SourceConfigFn>
---@param aggregate_prompt string|nil
function M.execute_sources(source_configs, aggregate_prompt, callback)
  aggregate_prompt = aggregate_prompt or ""
  if #source_configs == 0 then
    callback(aggregate_prompt)
  else
    local source = table.remove(source_configs, 1)
    local source_callback = function(input)
      input = input or ""
      M.execute_sources(source_configs, aggregate_prompt .. input, callback)
    end
    source(source_callback)
  end
end

return M
