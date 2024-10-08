require('matcher_combinators.luassert')
local H = require('chatty-ai.history')

describe('history normalize', function()
  it('does not change empty history', function()
    local empty_history = {}
    assert.same(H.normalize_history(empty_history), empty_history)
  end)

  it('does not change valid history', function()
    local normal_history = {
      {
        type = 'user',
        text = 'lintf is not a valid function'
      },
      {
        type = 'assistant',
        text = 'neovim buffer type cs'
      },
      {
        type = 'user',
        text = 'Please fix the following code. void main() { lintf("poop\n"); }'
      },
    }
    local normalized_history = H.normalize_history(normal_history)
    assert.are.same(normalized_history, normal_history)
  end)

  it('collapses when all prompts', function()
    local history = {
      {
        type = 'user',
        text = 'lintf is not a valid function'
      },
      {
        type = 'user',
        text = 'neovim buffer type cs'
      },
      {
        type = 'user',
        text = 'Please fix the following code. void main() { lintf("poop\n"); }'
      },
    }
    local expected = {
      {
        type = 'user',
        text = 'lintf is not a valid function\n' ..
                'neovim buffer type cs\n' ..
                'Please fix the following code. void main() { lintf("poop\n"); }'
      },
    }
    local normalized_history = H.normalize_history(history)
    assert.are.same(normalized_history, expected)
  end)

  it('collapses mixtures of prompts', function()
    local history = {
      {
        type = 'assistant',
        text = 'lintf is not a valid function'
      },
      {
        type = 'assistant',
        text = 'neovim buffer type cs'
      },
      {
        type = 'user',
        text = 'Please fix the following code. void main() { lintf("poop\n"); }'
      },
    }
    local expected = {
      {
        type = 'assistant',
        text = 'lintf is not a valid function\n' ..
                'neovim buffer type cs'
      },
      {
        type = 'user',
        text = 'Please fix the following code. void main() { lintf("poop\n"); }'
      },
    }
    local normalized_history = H.normalize_history(history)
    assert.are.same(normalized_history, expected)
  end)

end)
