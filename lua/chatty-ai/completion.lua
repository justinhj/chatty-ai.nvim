local M = {}

local L = require('plenary.log')
local curl = require('plenary.curl')
local log = L.new({ plugin = 'chatty-ai' })
local sources = require('chatty-ai.sources')
local targets = require('chatty-ai.targets')
local util = require('chatty-ai.util')
local history = require('chatty-ai.history')

local ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages'
local OPENAI_URL = 'https://api.openai.com/v1/chat/completions'

---@enum CompletionResultType
local CompletionResultType = {
  FIRST = 1,
  CONTINUATION = 2,
  LAST = 3,
}

---@class CompletionResult
---@field text string
---@field type CompletionResultType

---@type Job
M.current_job = nil

-- TODO move
-- local function process_data_lines(line, process_data)
-- 	local json = line:match("^data: (.+)$")
-- 	if json then
-- 		local stop = false
-- 		if json == "[DONE]" then
-- 			return true
-- 		end
-- 		local data = vim.json.decode(json)
--     stop = data.type == "message_stop"
-- 		if stop then
-- 			return true
-- 		else
-- 			vim.schedule(function()
-- 				vim.cmd("undojoin") -- TODO what is this for
-- 				process_data(data)
-- 			end)
-- 		end
-- 	end
-- 	return false
-- end

local function extract_text(history)
    local result = {}
    for _, entry in ipairs(history) do
        if entry.text then
            table.insert(result, entry.text)
        end
    end
    return table.concat(result, '\n')
end

---@param user_prompt string
---@param completion_config CompletionConfig
---@param anthropic_config AnthropicConfig
---@param is_stream boolean
M.anthropic_completion = function(user_prompt, completion_config, anthropic_config, is_stream, global_config, on_complete)
  local done = false
  local res = nil
  local succ = nil

  log.debug('user prompt ' .. vim.inspect(user_prompt))

  -- Temporary, convert the user prompt to just a single user entry
  -- TODO this should convert the history table into the anthropic messages format
  user_prompt = extract_text(user_prompt)

  log.debug('user prompt ' .. user_prompt)

  if M.current_job then
    M.current_job:shutdown()
    M.current_job = nil
  end

  local stream = nil
  local complete_callback = nil
  local error_callback = nil

  local stream_callback = function (error, chunk)
    log.debug('anthropic stream processing')
    if error then
      log.debug('received error in anthropic stream ' .. vim.inspect(error))
    else
      local data_raw = string.match(chunk, "data: (.+)")

      if data_raw then
        local data = vim.json.decode(data_raw)

        local content = ''
        if data.delta and data.delta.text then
          content = data.delta.text
          log.debug('streaming ' .. content)
          on_complete(content)

          -- local lines = vim.split(content, "\n")
          -- vim.schedule(function ()
          --   pcall(function() vim.cmd("undojoin") end)
          --   vim.api.nvim_put(lines, "c", true, true)
          -- end)
        end
      end
    end
  end

  if is_stream then
    stream = vim.schedule_wrap(stream_callback)

    error_callback = function(err)
      log.error('error callback' .. tostring(err))
      M.current_job = nil
    end

    complete_callback = function(out)
      -- note that the streaming call back just logs output for now
      -- TODO it should return generic usage info
      log.debug('streaming complete callback')
      -- TODO check for error response
      -- data: {"type":"error","error":{"details":null,"type":"overloaded_error","message":"Overloaded"}
    end
  else
    complete_callback = function (out)
      log.debug('synchronous complete callback: ' .. tostring(out.status))
      local content = nil
      if out and out.status == 200 then
        vim.schedule(function ()
          local response = vim.fn.json_decode(out.body)
          content = response.content
          if content[1].type == 'text' then
            on_complete(content[1].text)
          else
            -- TODO ???
            on_complete("no text")
          end
        end)
      end
    end
  end

  local body = {
      stream = is_stream,
      model = 'claude-3-5-sonnet-20240620', -- todo should be configurable
      messages = {
        {
          content = completion_config.prompt .. '\n' .. user_prompt,
          role = 'user',
        },
      },
      max_tokens = 4096,
      system = completion_config.system,
      temperature = 1.0, -- between 0.0 and 1.0 where higher is more creative
    }

  log.debug('body ' .. vim.inspect(body))

  M.current_job = curl.post(ANTHROPIC_URL, {
    headers = {
      ['x-api-key'] = anthropic_config.api_key_value,
      ['content-type'] = 'application/json',
      ['anthropic-version'] = anthropic_config.version,
    },
    body = vim.fn.json_encode(body),
    stream = stream,
    callback = complete_callback,
    on_error = error_callback,
  })

  log.debug('job started')

  -- if stream then
  --   log.debug('async return')
  --   return
  -- end

  -- vim.wait(global_config.timeout_ms, function()
  --   return done
  -- end, 100) -- todo config interval and cancellation with ESC key

  -- log.debug('done waiting ' .. tostring(succ) .. ' ' .. tostring(res ~= nil))

  -- local response = nil
  -- if succ and res then
  --   response = vim.fn.json_decode(res.body)
  --   local content = response.content
  --   if content[1].type == 'text' then
  --     return content[1].text
  --   end
  -- end
end

-- Anthropic API errors
-- local status_codes = {
--     [400] = {error_type = "invalid_request_error", message = "There was an issue with the format or content of your request. We may also use this error type for other 4XX status codes not listed below."},
--     [401] = {error_type = "authentication_error", message = "There's an issue with your API key."},
--     [403] = {error_type = "permission_error", message = "Your API key does not have permission to use the specified resource."},
--     [404] = {error_type = "not_found_error", message = "The requested resource was not found."},
--     [413] = {error_type = "request_too_large", message = "Request exceeds the maximum allowed number of bytes."},
--     [429] = {error_type = "rate_limit_error", message = "Your account has hit a rate limit."},
--     [500] = {error_type = "api_error", message = "An unexpected error has occurred internal to Anthropic's systems."},
--     [529] = {error_type = "overloaded_error", message = "Anthropic's API is temporarily overloaded."}
-- }

-- Error response
-- {
--   "type": "error",
--   "error": {
--     "type": "not_found_error",
--     "message": "The requested resource could not be found."
--   }
-- }

-- Note that the request id `request-id` in the response headers can be used for technical support.

-- Response headers

-- anthropic-ratelimit-requests-limit	The maximum number of requests allowed within any rate limit period.
-- anthropic-ratelimit-requests-remaining	The number of requests remaining before being rate limited.
-- anthropic-ratelimit-requests-reset	The time when the request rate limit will reset, provided in RFC 3339 format.
-- anthropic-ratelimit-tokens-limit	The maximum number of tokens allowed within the any rate limit period.
-- anthropic-ratelimit-tokens-remaining	The number of tokens remaining (rounded to the nearest thousand) before being rate limited.
-- anthropic-ratelimit-tokens-reset	The time when the token rate limit will reset, provided in RFC 3339 format.
-- retry-after	The number of seconds until you can retry the request.

-- Success response
-- {
--   "content": [
--     {
--       "text": "Hi! My name is Claude.",
--       "type": "text"
--     }
--   ],
--   "id": "msg_013Zva2CMHLNnXjNJJKqJ2EF",
--   "model": "claude-3-5-sonnet-20240620",
--   "role": "assistant",
--   "stop_reason": "end_turn",
--   "stop_sequence": null,
--   "type": "message",
--   "usage": {
--     "input_tokens": 10,
--     "output_tokens": 25
--   }
-- }

-- Chat completion object (not streaming)
-- {
--   "id": "chatcmpl-123",
--   "object": "chat.completion",
--   "created": 1677652288,
--   "model": "gpt-4o-mini",
--   "system_fingerprint": "fp_44709d6fcb",
--   "choices": [{
--     "index": 0,
--     "message": {
--       "role": "assistant",
--       "content": "\n\nHello there, how may I assist you today?",
--     },
--     "logprobs": null,
--     "finish_reason": "stop"
--   }],
--   "usage": {
--     "prompt_tokens": 9,
--     "completion_tokens": 12,
--     "total_tokens": 21
--   }
-- }

---@param user_prompt string
---@param completion_config CompletionConfig
---@param openai_config OpenAIConfig
---@param is_stream boolean
M.openai_completion = function(user_prompt, completion_config, openai_config, is_stream, global_config)
  local done = false
  local res = nil
  local succ = nil

  if M.current_job then
    M.current_job:shutdown()
    M.current_job = nil
  end

  local stream = nil
  local complete_callback = nil
  local error_callback = nil

  if is_stream then
    log.error('streaming not supported yet')
    -- stream = process_openai_stream

    -- error_callback = function(err)
    --   log.error('error callback' .. tostring(err))
    --   M.current_job = nil
    -- end

    -- complete_callback = function(out)
    --   log.debug('completed streaming callback ' .. tostring(out))

    --   vim.schedule(function()
    --     -- write_string_at_cursor(out)
    --     -- this is the full response from the job as a table with status, body, headers and exit
    --     -- note that headers is a table but body is escaped json

    --     vim.print(out)
    --   end)
    -- end
  else
    complete_callback = function(out)
      log.debug('completion sync callback ' .. vim.inspect(out))
      done = true
      succ = out.status == 200
      res = out
    end
  end

  -- TODO system prompt should be added in the body as a message
  local body = {
      stream = is_stream,
      model = 'gpt-4o', -- todo config
      messages = {
        {
          content = completion_config.prompt .. '\n' .. user_prompt,
          role = 'user',
        },
      },
      max_tokens = 2000, -- note 4096 is the max
      -- system = completion_config.system,
      temperature = 1.0, -- between 0.0 and 1.0 where higher is more creative
    }

  log.debug('body ' .. vim.inspect(body))

  M.current_job = curl.post(OPENAI_URL, {
    headers = {
      ['Authorization'] = 'Bearer ' .. openai_config.api_key_value,
      ['content-type'] = 'application/json',
    },
    body = vim.fn.json_encode(body),
    stream = stream,
    callback = complete_callback,
    on_error = error_callback,
  })

  log.debug('job started')

  if stream then
    log.debug('async return')
    return "async job lol" -- todo
  end

  vim.wait(global_config.timeout_ms, function()
    return done
  end,
  100) -- todo config interval and cancellation with key

  log.debug('done waiting ' .. tostring(succ) .. ' ' .. tostring(res ~= nil))

  local response = nil
  if succ and res then
    response = vim.fn.json_decode(res.body)

    log.debug('response ' .. vim.inspect(response.choices))

    local choice = response.choices[1] -- note pass n > 1 and you can choose from multiple
    return choice.message.content
  end
  return "error" -- todo error handling, should call the targets error callback
end

--TODO DESIGN should_stream should be part of config called target_config?

---@param should_stream boolean
function M.completion_job(global_config, service_config, source_config, completion_config, target_config, should_stream)

  -- TODO at this point call something in targets that may take action based on the configuration
  -- For a hacky example let's erase the current selection if there is one
  -- it should generally just set things up for writing

  -- When mode is streaming delete the visual selection and stream there
  if should_stream and util.is_visual_mode() then
    vim.api.nvim_command("normal! d")
  end

  -- Note that because sources can be async, we must treat them all as async. The 
  -- completion job needs this partial function which will be called with the result
  -- of the execute sources call
  local target_cb = targets.get_callback(target_config)
  local complete_cb = function(prompt)
    -- TODO think about how prompts should be added. Just append, or insert, and handle de-duplication
    history.append_entries(prompt)

    -- local result =
    service_config.completion_fn(prompt, completion_config, service_config, should_stream, global_config, target_cb)

    -- if type(result) == 'string' and not should_stream then -- TODO get rid of this with final target implementation
    --   target_cb(result)
    -- end
  end

  sources.execute_sources(source_config, complete_cb)
end

return M
