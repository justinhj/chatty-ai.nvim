require('matcher_combinators.luassert')
local S = require('chatty-ai.services')

describe('service management', function()
  before_each(function()
  end)

  after_each(function()
  end)

  local test_service_name = 'binky-ai'

  it('creates a service', function()
    local s = S.new(test_service_name, {})
    assert.are.same(s.name, test_service_name)

  end)

end)
