rockspec_format = '3.0'
package = "chatty-ai.nvim"
version = "0.0.1"
source = {
  -- TODO: Update this URL
  url = "git+https://github.com/justinhj/chatty-ai.nvim"
}
dependencies = {
  "nvim-lua/plenary.nvim"
}
test_dependencies = {
  "nlua"
}
build = {
  type = "builtin",
  copy_directories = {
    -- Add runtimepath directories, like
    -- 'plugin', 'ftplugin', 'doc'
    -- here. DO NOT add 'lua' or 'lib'.
  },
}
