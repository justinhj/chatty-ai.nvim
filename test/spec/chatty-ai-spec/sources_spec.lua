require('matcher_combinators.luassert')
local mock = require('luassert.mock')
local S = require('chatty-ai.sources')

local function execute_single_source(source)
  local result
  local function cb(s)
    result = s
  end
  source(cb)
  return result
end

describe('filetype source', function()
  local api
  local prefix = 'Infer the programming language from the filetype: '

  before_each(function()
    api = mock(vim.api, true)
  end)

  after_each(function()
    mock.revert(api)
  end)

  it('detects markdown', function()
    api.nvim_buf_get_name.returns('/root/files/README.md')
    assert.equals(execute_single_source(S.filetype), prefix .. 'markdown')
  end)

  it('detects lua', function()
    api.nvim_buf_get_name.returns('/root/files/file.lua')
    assert.equals(execute_single_source(S.filetype), prefix .. 'lua')
  end)
end)
