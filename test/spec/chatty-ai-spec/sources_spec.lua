require('matcher_combinators.luassert')

local double = function(x)
  return x * 2
end

describe('chooser', function()
  it('maximum', function()
    assert.equals(double(6), 12)
  end)
end)
