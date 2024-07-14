local log = require('plenary.log').new({
  plugin = 'my_plugin',
  level = 'debug',
})

-- log.debug("This is a debug message")
-- log.info("This is an info message")
-- log.warn("This is a warning message")
-- log.error("This is an error message")

-- local l = vim.fn.getenv("DEBUG_PLENARY")
-- print("l " .. type(l))

local function test(a)
  return a, a + 1
end

-- local b, c = test(1)
-- print(b,c)

local bit = require('bit')

local function is_readable_directory(file)
  local s = vim.loop.fs_stat(file)
  return s ~= nil and s.type == 'directory' and bit.band(s.mode, 4) == 4
end

local dirs = { '.', 'poop', '/sys/class/power_supply/', '/sys/class/power_supply/BAT0' }
for _, dir in ipairs(dirs) do
  print(dir, is_readable_directory(dir) == true)
end
