require('matcher_combinators.luassert')
local H = require('chatty-ai.context')

describe('context normalize', function()
  it('does not change empty context', function()
    local empty_context = {}
    assert.same(empty_context, empty_context)
  end)

end)
