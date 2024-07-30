local M = {}

local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })

-- Sources provide ways to get the prompt to send to chatty
-- TODO change the name to input
function M.prompt_ui(callback)
  vim.ui.input({prompt = 'Enter a prompt: '}, callback)
end

-- TODO think about how to concatenate multiple sources as they go along
-- This would allow something like the get buffer type source + the prompt or selection source

---@param source_config table<SourceConfigFn>
function M.execute_sources(source_config, callback)
  if #source_config == 0 then
    log.error('No source configs')
  else
    source_config[1](function(prompt)
      if prompt == nil then
        log.error('Prompt was nil')
      else
        callback(prompt)
      end
    end)
  end
end

return M
