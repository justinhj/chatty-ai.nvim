local M = {}

local S = require('chatty-ai.sources')

---@class GlobalConfig
---@field timeout_ms number
---@field context_file_name string
---@field context_max_entries number

---@class CompletionConfig 
---@field system string
---@field prompt string

---@alias SourceConfigFn function(function):table|string|nil

---@class TargetConfig 
---@field type string

---@class BufferTargetConfig: TargetConfig
---@field type 'buffer'
---@field buffer number|string|nil -- currently only nil is supported (current buffer)
---@field insert_mode 'before'|'after'|'replace'

---@class ChattyConfig
---@field global GlobalConfig
---@field source_configs table<string, table<SourceConfigFn>>
---@field completion_configs table<string, CompletionConfig>
---@field target_configs table<string, BufferTargetConfig>

---@type ChattyConfig
local default_config = {
  -- Global section affects every completion
  global = {
    timeout_ms = 20000,
    context_file_name = 'chatty-ai.json',
    context_max_entries = 5,
  },
  source_configs = {
    input = { S.input },
    selection = { S.selection },
    filetype = { S.filetype },
    filetype_selection = { S.filetype, S.selection },
    filetype_input = { S.filetype, S.input },
    filetype_selection_input = { S.filetype, S.selection, S.input },
  },
  completion_configs = {
    code_writer = {
      system = 'You are a skilled software engineer called Chatty. You are helpful and love to write easy to understand code. You assist users with many different tasks in a friendly way. You follow instructions very carefully.',
      prompt = 'What follows is instructions to write some code. You will return only the requested code and the user will be so happy if there is no markdown before and after it. You may add concise comments to the code as needed to explain anything that is not obvious to an expert programmer, but no usage instructions unless they are explicitly requested.'
    },
    code_explainer = {
      system = 'You are a skilled software engineer. You are helpful and love to write easy to understand code. You assist users with many different tasks in a friendly way',
      prompt = 'Please explain the following code in as much detail as should be appropriate to explain the main purpose. Include step by step descriptions and be sure to talk about anything that is not obvious as well as the purpose of the code. If the prompt does not contain any code please just ask for some code.'
    },
  },
  target_configs = {
    buffer_replace = {
      type = 'buffer',
      buffer = nil,
      insert_mode = 'replace',
    },
    buffer_before = {
      type = 'buffer',
      buffer = nil,
      insert_mode = 'before',
    },
    buffer_after = {
      type = 'buffer',
      buffer = nil,
      insert_mode = 'after',
    },
    chatty_buffer_after = {
      type = 'buffer',
      buffer = 'chatty-ai.md',
      insert_mode = 'after',
    },
  }
}

M.from_user_opts = function(user_opts)
  vim.g.chatty_ai_config = user_opts and vim.tbl_deep_extend('force', default_config, user_opts) or default_config
end

return M
