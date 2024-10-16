if vim.fn.has("nvim-0.9") == 0 then
  vim.api.nvim_err_writeln("chatty-ai requires at least nvim-0.9")
  return
end

-- make sure this file is loaded only once
if vim.g.chatty_ai_plugin_loaded then
  return
end
vim.g.chatty_ai_plugin_loaded = 1

require('chatty-ai.chatty-ai').setup_user_commands()
