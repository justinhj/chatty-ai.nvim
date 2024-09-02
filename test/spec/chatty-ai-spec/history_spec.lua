require('matcher_combinators.luassert')
local H = require('chatty-ai.history')

describe('history normalize', function()
  it('does not change valid or empty history', function()
    local empty_history = {}
    assert.same(H.normalize_history(empty_history), empty_history)
  end)
end)
