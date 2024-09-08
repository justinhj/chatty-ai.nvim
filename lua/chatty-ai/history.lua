-- Manages the chat history
local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local Path = require('plenary.path')

local M = {}

local valid_types = { 'user', 'assistant' }
local function is_valid_type(type)
  for _, valid_type in ipairs(valid_types) do
    if type == valid_type then
      return true
    end
  end
  return false
end

-- Ensure the plugin path exists (could be done in config setup actually)
-- and return it
local function get_or_create_chatty_path()
  local path = vim.fn.stdpath('data') .. "/chatty-ai"
  local p = Path:new(path)
  if p:exists() and not p:is_dir() then
    error("chatty's data path exists but is not a directory")
  elseif not p:exists() then
    p:mkdir()
  end
  return path
end

function M.show_history()
  if(vim.g.chatty_ai_config.global.history_file_name == nil) then
    log.info('no history file will not use history')
  end
  local path = get_or_create_chatty_path()
  local history_file_name = vim.g.chatty_ai_config.global.history_file_name

  local p = Path:new(path .. '/' .. history_file_name)

  if not p:exists() then
    local file = io.open(p.filename, 'w+')
    if not file then
      error('Could not create history file')
    end
    file:write(vim.fn.json_encode({}))
    file:close()
  end

  vim.cmd('edit ' .. p.filename)
end

function M.load_history()
  if(vim.g.chatty_ai_config.global.history_file_name == nil) then
    log.debug('no history file will not use history')
  end
  local path = get_or_create_chatty_path()
  local history_file_name = vim.g.chatty_ai_config.global.history_file_name

  local p = Path:new(path .. '/' .. history_file_name)

  if not p:exists() then
    log.debug('History not written yet')
    return {}
  end

  local file = io.open(p.filename, 'r')
  if not file then
    error('Could not open history file')
  end
  local history = vim.fn.json_decode(file:read('*a'))
  file:close()

  return history
end

function M.write_history(history)
  if(vim.g.chatty_ai_config.global.history_file_name == nil) then
    log.debug('no history file will not write history')
  end
  local path = get_or_create_chatty_path()
  local history_file_name = vim.g.chatty_ai_config.global.history_file_name

  local p = Path:new(path .. '/' .. history_file_name)

  local file = io.open(p.filename, 'w+')
  if not file then
    error('Could not open history file')
  end
  file:write(vim.fn.json_encode(history))
  file:close()

  return history
end

-- This takes care of ensuring a history alternates between user and assistant prompts
-- Consecutive user or assistant prompts are merged together
function M.normalize_history(history)
  assert(type(history) == 'table', 'history must be a table')
  local normalized_history = {}

  log.debug('normalizing ' .. vim.inspect(history))

  local previous_type = nil
  for _, entry in ipairs(history) do
    if entry.type and is_valid_type(entry.type) then
      -- Merge consecutive entries of the same type
      if previous_type == entry.type then
        local last_entry = normalized_history[#normalized_history]
        if last_entry.type == entry.type then
          last_entry.text = last_entry.text .. '\n' .. entry.text
        end
      else
        table.insert(normalized_history, entry)
      end
      previous_type = entry.type
    else
      log.warn('history entry must have a type field with value "user" or "assistant"')
    end
  end

  return normalized_history
end

-- Append a new entry to the chat history
function M.append_entry(entry)
  assert(type(entry) == 'table', 'entry must be a table')
  assert(entry.type, 'entry must have a type field')
  assert(entry.text, 'entry must have a text field')
  assert(is_valid_type(entry.type), 'entry type must be "user" or "assistant"')
  local history = M.load_history()
  table.insert(history, entry)
  local new_history = M.normalize_history(history)
  M.write_history(new_history)
end
return M
