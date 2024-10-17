local M = {}

-- copied from plenary luassert.util
function M.shallowcopy(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  setmetatable(copy, getmetatable(t))
  for k,v in next, t do
    copy[k] = v
  end
  return copy
end

-- move to util if it's useful
function M.is_visual_mode()
    local mode = vim.fn.mode()
    return mode == 'v' or mode == 'V' or mode == '\22'
end

function M.find_string_in_table(tbl, str)
    for i, value in ipairs(tbl) do
        if type(value) == "string" and value == str then
            return i
        end
    end
    return nil
end

-- This is based on similar code in the fzf-lua project with some modifications
-- for chatty-ai. In particular if no lines are returned or we are not in visual
-- mode we return nil, nil
---@return string|nil, table|nil
function M.get_visual_selection()
  local _, csrow, cscol, cerow, cecol
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "" then
    -- if we are in visual mode use the live position
    _, csrow, cscol, _ = unpack(vim.fn.getpos("."))
    _, cerow, cecol, _ = unpack(vim.fn.getpos("v"))
    if mode == "V" then
      -- visual line doesn't provide columns
      cscol, cecol = 0, 999
    end
  else
    -- When not in visual mode we want nothing
    return nil, nil
  end
  -- Ensure the rows and cols are in the correct order
  if cerow < csrow then csrow, cerow = cerow, csrow end
  if cecol < cscol then cscol, cecol = cecol, cscol end
  local lines = vim.fn.getline(csrow, cerow)
  local n = #lines
  if n <= 0 then return nil, nil end
  lines[n] = string.sub(lines[n], 1, cecol)
  lines[1] = string.sub(lines[1], cscol)
  return table.concat(lines, "\n"), {
    start   = { line = csrow, char = cscol },
    ["end"] = { line = cerow, char = cecol },
  }
end

return M
