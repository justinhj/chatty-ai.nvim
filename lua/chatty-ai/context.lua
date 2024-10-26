-- Manages the chat context
local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local Path = require('plenary.path')

local M = {}

local function refresh_context(filename)
  local bufnr = vim.fn.bufnr(filename)
  if bufnr ~= -1 then
    vim.api.nvim_command('checktime ' .. bufnr)
  end
end

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

function M.clear_context()
  if(vim.g.chatty_ai_config.global.context_file_name == nil) then
    log.info('no context file will not use context')
    return
  end
  local path = get_or_create_chatty_path()
  local context_file_name = vim.g.chatty_ai_config.global.context_file_name

  local p = Path:new(path .. '/' .. context_file_name)

  local file = io.open(p.filename, 'w+')
  if not file then
    error('Could not create context file')
  end
  file:write(vim.fn.json_encode({}))
  file:close()

  -- Note this opens the buffer, including a new window for it even if it already has one
  -- vim.cmd('edit ' .. p.filename)
  -- This just reloads it if it is loaded
  vim.cmd('checktime')
end

function M.show_context()
  if(vim.g.chatty_ai_config.global.context_file_name == nil) then
    log.info('no context file will not use context')
    return
  end
  local path = get_or_create_chatty_path()
  local context_file_name = vim.g.chatty_ai_config.global.context_file_name

  local p = Path:new(path .. '/' .. context_file_name)

  if not p:exists() then
    local file = io.open(p.filename, 'w+')
    if not file then
      error('Could not create context file')
    end
    file:write(vim.fn.json_encode({}))
    file:close()
  end

  vim.cmd('edit ' .. p.filename)
end

function M.load_context()
  if(vim.g.chatty_ai_config.global.context_file_name == nil) then
    log.debug('no context file will not use context')
    return nil
  end
  local path = get_or_create_chatty_path()
  local context_file_name = vim.g.chatty_ai_config.global.context_file_name

  local p = Path:new(path .. '/' .. context_file_name)

  if not p:exists() then
    log.debug('context not written yet')
    return {}
  end

  local file = io.open(p.filename, 'r')
  if not file then
    error('Could not open context file')
  end
  local context = vim.fn.json_decode(file:read('*a'))
  file:close()

  return context
end

function M.write_context(context)
  if(vim.g.chatty_ai_config.global.context_file_name == nil) then
    log.error('no context file will not write context')
    return nil
  end
  local path = get_or_create_chatty_path()
  local context_file_name = vim.g.chatty_ai_config.global.context_file_name

  local p = Path:new(path .. '/' .. context_file_name)

  local file = io.open(p.filename, 'w+')
  if not file then
    error('Could not open context file')
  end
  file:write(vim.fn.json_encode(context))
  file:close()

  refresh_context(p.filename)

  return context
end

-- This takes care of ensuring a context alternates between user and assistant prompts
-- Consecutive user or assistant prompts are merged together
function M.normalize_context(context)
  assert(type(context) == 'table', 'context must be a table')
  local normalized_context = {}

  log.debug('normalizing ' .. vim.inspect(context))

  local previous_type = nil
  for _, entry in ipairs(context) do
    if entry.type and is_valid_type(entry.type) then
      -- Merge consecutive entries of the same type
      if previous_type == entry.type then
        local last_entry = normalized_context[#normalized_context]
        if last_entry.type == entry.type then
          last_entry.text = last_entry.text .. '\n' .. entry.text
        end
      else
        table.insert(normalized_context, entry)
      end
      previous_type = entry.type
    else
      log.warn('context entry must have a type field with value "user" or "assistant"')
    end
  end
  return normalized_context
end

-- Append a table of entries to the chat context
function M.append_entries(entries)
  assert(type(entries) == 'table', 'entries must be a table')
  local context = M.load_context()
  log.debug('appending entries to context: ' .. vim.inspect(entries))
  if context ~= nil then
    for _, entry in ipairs(entries) do
      assert(entry.type, 'entry must have a type field')
      assert(entry.text, 'entry must have a text field')
      assert(is_valid_type(entry.type), 'entry type must be "user" or "assistant"')
      log.debug('appending entry: ' .. vim.inspect(entry))
      table.insert(context, entry)
    end
    local new_context = M.normalize_context(context)
    M.write_context(new_context)
  end
end
return M
