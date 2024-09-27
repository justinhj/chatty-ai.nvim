local M = {}

local chatty_ai = require('chatty-ai.chatty-ai')

M.complete = chatty_ai.complete
M.setup = chatty_ai.setup
M.status = chatty_ai.get_status

return M
