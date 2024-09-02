local M = {}

local U = require('chatty-ai.util')
local L = require('plenary.log')
local FT = require('plenary.filetype')
local log = L.new({ plugin = 'chatty-ai' })

-- Sources provide ways to get the prompt to send to chatty; they return nil if they
-- have nothing to add to the prompt, or a string prompt or a table that contains a
-- list of entries matching the format of the chat history. See history.lua
-- After gathering all the sources, all of the user prompts are concatenated together
-- and consecutive user prompts are merged together (Since most message apis require
-- alternating between user and assistant prompts)
-- TODO DESIGN does it need to configure?
function M.input(callback)
  vim.ui.input({prompt = 'Enter a prompt: '}, callback)
end

function M.selection(callback)
  log.debug('getting visual selection')
  local lines, _ = U.get_visual_selection()
  log.debug('got visual selection: ' .. vim.inspect(lines))
  callback(lines)
end

function M.filetype(callback)
  log.debug('getting filetype')
  -- use plenary to get the filetype
  local filetype = FT.detect(vim.api.nvim_buf_get_name(0))
  if filetype then
    log.debug('got filetype: ' .. filetype)
    callback('Guess the programming language from neovim filetype ' .. filetype .. '\n')
  else
    log.debug('no filetype detected')
    callback(nil)
  end
end

local function execute_sources_internal(source_configs, aggregate_prompt, callback)
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
-- As explained above prompts are either strings or tables. We convert the strings
-- to tables and then ensure that all the user prompts are merged together

---@param source_configs table<SourceConfigFn>
---@param aggregate_prompt string|nil
function M.execute_sources(source_configs, aggregate_prompt, callback)
  -- Note that source configs table is mutated so we need to copy it
  local source_configs_copy = U.shallowcopy(source_configs)
  execute_sources_internal(source_configs_copy, aggregate_prompt, callback)
end

return M
