-- Manages the chat context
local L = require('plenary.log')
local log = L.new({ plugin = 'chatty-ai' })
local Path = require('plenary.path')
local Sources = require('chatty-ai.sources')
local Util = require('chatty-ai.util')

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

-- Function to set the context filename, ensuring it ends with .json
function M.set_name(name)
  local base_name = name:match("(.+)%..+") or name
  base_name = base_name .. '.json'
  local c = vim.g.chatty_ai_config
  local gc = c.global
  log.debug('setting context file name to ' .. base_name .. ' it was ' .. gc.context_file_name)
  gc.context_file_name = base_name
  c.global = gc
  vim.g.chatty_ai_config = c
  log.debug('context name is now ' .. vim.inspect(vim.g.chatty_ai_config.global))
end

-- Clear elements from the context except those in the except table
---@param except table<string>|nil
function M.clear_context(except)
  local config = vim.g.chatty_ai_config

  if(config.global.context_file_name == nil) then
    log.info('no context file will not use context')
    return
  end
  -- local path = get_or_create_chatty_path()
  -- local context_file_name = vim.g.chatty_ai_config.global.context_file_name

  -- local p = Path:new(path .. '/' .. context_file_name)

  -- local file = io.open(p.filename, 'w+')
  -- if not file then
  --   error('Could not create context file')
  -- end
  -- file:write(vim.fn.json_encode({}))
  -- file:close()

  local exceptions = except or {}
  M.remove_entries_except_with_type(exceptions)

  -- Add the default system prompt
  if(config.default_system_prompt ~= nil) then
    if config.system_prompts[config.default_system_prompt] == nil then
      error("System prompt '" .. config.default_system_prompt .. "' does not exist in config.system_prompts")
    else
      M.set_system_prompt(config.system_prompts[config.default_system_prompt])
    end
  end

  -- Note this opens the buffer, including a new window for it even if it already has one
  -- vim.cmd('edit ' .. p.filename)
  -- This just reloads it if it is loaded
  vim.cmd('checktime')
end

function M.show_context()
  if(vim.g.chatty_ai_config.global.context_file_name == nil) then
    log.info('no context file will not use context')
    return
  else
    log.debug('showing context ' .. vim.g.chatty_ai_config.global.context_file_name)
  end

  local context = M.load_context()
  if not context then
    context = {}
  end

  -- Get screen dimensions
  local width = vim.o.columns
  local height = vim.o.lines

  -- Calculate window size with 4-5 char margins
  local win_width = width - 10  -- 5 char margin on each side
  local win_height = height - 6  -- Leave room for header, footer, and margins
  local row = 2  -- Start a bit down from top
  local col = 5  -- 5 char left margin

  -- Create buffer for the popup
  local buf = vim.api.nvim_create_buf(false, true)

  -- Function to format context entries as structured text
  local function format_context_entry(entry, index)
    local lines = {}
    table.insert(lines, string.format("[%d] %s:", index, string.upper(entry.type or "unknown")))

    -- Split text into lines and indent
    local text = entry.text or ""
    for line in text:gmatch("[^\r\n]+") do
      table.insert(lines, "  " .. line)
    end

    table.insert(lines, "")  -- Empty line between entries
    return lines
  end

  -- Build content lines
  local context_file_name = vim.g.chatty_ai_config.global.context_file_name
  local separator_length = #context_file_name -- Get the length of the context_file_name string
  local separator_line = string.rep("═", separator_length) -- Create a string of "═" characters matching the length

  local content_lines = {context_file_name, separator_line, ""}

  if #context == 0 then
    table.insert(content_lines, "No context entries found.")
  else
    for i, entry in ipairs(context) do
      local entry_lines = format_context_entry(entry, i)
      for _, line in ipairs(entry_lines) do
        table.insert(content_lines, line)
      end
    end
  end

  -- Add footer
  table.insert(content_lines, "")
  table.insert(content_lines, "Press 'q' to close")

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)

  -- Set buffer options
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'

  -- Create floating window
  local win_opts = {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Context ',
    title_pos = 'center'
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Set window options
  vim.api.nvim_win_set_option(win, 'wrap', true)
  vim.api.nvim_win_set_option(win, 'cursorline', true)

  -- Set up syntax highlighting for better readability
  vim.api.nvim_buf_set_option(buf, 'filetype', 'chatty-context')

  -- Define custom syntax highlighting
  vim.cmd([[
    syntax match ChattyContextHeader /^Context$/
    syntax match ChattyContextSeparator /^═\+$/
    syntax match ChattyContextEntryHeader /^\[\d\+\] \w\+:$/
    syntax match ChattyContextFooter /^Press 'q' to close$/

    highlight link ChattyContextHeader Title
    highlight link ChattyContextSeparator Comment  
    highlight link ChattyContextEntryHeader Identifier
    highlight link ChattyContextFooter Comment
  ]])

  -- Set up key mapping to close with 'q'
  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Set buffer-local keymap for 'q'
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
    noremap = true,
    silent = true,
    callback = close_window
  })

  -- Also handle escape key
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
    noremap = true,
    silent = true,
    callback = close_window
  })

  -- Set cursor to top of content (after header)
  vim.api.nvim_win_set_cursor(win, {3, 0})
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
-- function M.normalize_context(context)
--   assert(type(context) == 'table', 'context must be a table')
--   local normalized_context = {}

--   log.debug('normalizing ' .. vim.inspect(context))

--   local previous_type = nil
--   for _, entry in ipairs(context) do
--     if entry.type and is_valid_type(entry.type) then
--       -- Merge consecutive entries of the same type
--       if previous_type == entry.type then
--         local last_entry = normalized_context[#normalized_context]
--         if last_entry.type == entry.type then
--           last_entry.text = last_entry.text .. '\n' .. entry.text
--         end
--       else
--         table.insert(normalized_context, entry)
--       end
--       previous_type = entry.type
--     else
--       log.warn('context entry must have a type field with value "user" or "assistant"')
--     end
--   end
--   return normalized_context
-- end

-- execute the provided sources and add them to the context
function M.add_sources(source_config_name)
  if vim.g.chatty_ai_is_setup ~= true then
    log.error('Please run setup')
    return
  end

  local function cb(prompts)
    M.append_entries(prompts)
  end

  local source_config = vim.g.chatty_ai_config.source_configs[source_config_name]
  if source_config ~= nil then
    Sources.execute_sources(source_config, cb)
  else
    log.error(source_config_name .. ' not found in source_configs')
  end
end

-- Sets a system prompt as the first context entry. If an existing system prompt
-- is found it will be replaced
function M.set_system_prompt(system_prompt)
  local system = system_prompt -- TODO string and table handling
  local context = M.load_context()
  log.debug('Setting system prompt: ' .. system)
  if context ~= nil then
    if #context > 0 and context[1].type == 'system' then
      context[1].text = system -- overwrite the current system prompt
    else
      table.insert(context, 1, { type = 'system', text = system })
    end
    M.write_context(context)
  end
end

-- Sets a prompt at the end of the context
-- is found it will be replaced
function M.set_prompt(prompt)
  local p = prompt -- TODO string and table handling
  local context = M.load_context()
  if not context then
    context = {}
  end
  log.debug('Adding prompt: ' .. p)
  table.insert(context, 1, { type = 'user', text = p })
  M.write_context(context)
end

-- Append a table of entries to the chat context
---@param except table<string>
function M.remove_entries_except_with_type(except)
  assert(type(except) == 'table', 'entries must be a table')
  local old_context = M.load_context() or {}
  local context = {}
  for _, entry in ipairs(old_context) do
    if Util.find_string_in_table(except, entry.type) then
      table.insert(context, entry)
    end
  end
  M.write_context(context)
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
    M.write_context(context)
  end
end
return M
