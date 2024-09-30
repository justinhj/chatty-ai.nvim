require('matcher_combinators.luassert')
local H = require('chatty-ai.context')

describe('context normalize', function()
  it('does not change empty context', function()
    local empty_context = {}
    assert.same(H.normalize_context(empty_context), empty_context)
  end)

  it('does not change valid context', function()
    local normal_context = {
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
    local normalized_context = H.normalize_context(normal_context)
    assert.are.same(normalized_context, normal_context)
  end)

  it('collapses when all prompts', function()
    local context = {
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
    local normalized_context = H.normalize_context(context)
    assert.are.same(normalized_context, expected)
  end)

  it('collapses mixtures of prompts', function()
    local context = {
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
    local normalized_context = H.normalize_context(context)
    assert.are.same(normalized_context, expected)
  end)

end)
