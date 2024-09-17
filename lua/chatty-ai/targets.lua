local M = {}

-- TODO this in progress
-- Behaviour expected:
-- If the buffer is new then create it
-- Otherwise open it in the current window (optionally split v or regular)
-- position the cursor at the end of the buffer or the beginning (before or after setting)
-- if replace mode then select the whole buffer and delete before insterting
-- put the text

local function write_string_at_cursor(window, str, mode)

  -- NOTE DESIGN for async this should only be done once
  -- TODO support for before and after
  -- TODO test if insert mode is active in the buffer to determine how to replace it
  if mode == 'replace' then
    vim.api.nvim_command("normal! d")
    vim.api.nvim_command("normal! o")
  end

	local cursor_position = vim.api.nvim_win_get_cursor(window)
	local row, col = cursor_position[1], cursor_position[2]

	local lines = vim.split(str, "\n")
	vim.api.nvim_put(lines, "c", true, true)

	local num_lines = #lines
	local last_line_length = #lines[num_lines]

	vim.api.nvim_win_set_cursor(window, { row + num_lines - 1, col + last_line_length })
end

local function get_or_create_buffer(buffer, filetype)
  if buffer == nil then
    local current_window = vim.api.nvim_get_current_win()
    local current_buffer = vim.api.nvim_win_get_buf(current_window)
    return current_buffer
  end

  local bufnr = vim.fn.bufnr(buffer)
  if bufnr == -1 then
      -- Buffer doesn't exist, create it
      bufnr = vim.fn.bufadd(buffer)
      vim.fn.bufload(bufnr)
  else
    return bufnr
  end
  -- New buffer only set the filetype and other settings

  if filetype then
      vim.api.nvim_set_option_value('filetype', filetype, { buf = bufnr })
  end
   -- Open the buffer in a new window if it's not already visible
  if vim.fn.bufwinnr(bufnr) == -1 then
      vim.cmd('buffer ' .. bufnr)
  end
  return bufnr
end

---@return function (): CompletionResult
function M.get_callback(target_config)
  if target_config.type == 'buffer' then
    return function (result)
      -- TODO this is first pass and pretty awful
      -- get_or_create_buffer(target_config.buffer, 'md')
      -- local current_window = vim.api.nvim_get_current_win()
      -- write_string_at_cursor(current_window, result, target_config.insert_mode)
      local lines = vim.split(result, "\n")
      -- vim.schedule(function ()
        pcall(function() vim.cmd("undojoin") end)
        vim.api.nvim_put(lines, "c", true, true)
      -- end)
    end
  else
    error("not implemented")
  end
end


return M
