local M = {}

local function write_string_at_cursor(str, mode)

  -- NOTE DESIGN for async this should only be done once
  if mode == 'replace' then
    vim.api.nvim_command("normal! d")
    vim.api.nvim_command("normal! o")
  end

	local current_window = vim.api.nvim_get_current_win()
	local cursor_position = vim.api.nvim_win_get_cursor(current_window)
	local row, col = cursor_position[1], cursor_position[2]

	local lines = vim.split(str, "\n")
	vim.api.nvim_put(lines, "c", true, true)

	local num_lines = #lines
	local last_line_length = #lines[num_lines]

	vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })

end

-- TODO Streaming support
function M.get_target_callback(target_config, should_stream)
  return function (result)
    if target_config.type == 'buffer' then
      local buffer = target_config.buffer
      write_string_at_cursor(result, target_config.insert_mode)
    end
  end
end


return M
