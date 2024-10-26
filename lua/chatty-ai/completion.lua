local M = {}

local L = require('plenary.log')
local curl = require('plenary.curl')
local log = L.new({ plugin = 'chatty-ai' })
local sources = require('chatty-ai.sources')
local targets = require('chatty-ai.targets')
local util = require('chatty-ai.util')
local CONTEXT = require('chatty-ai.context')
local services = require('chatty-ai.services')

local ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages'
local OPENAI_URL = 'https://api.openai.com/v1/chat/completions'

---@type Job
M.current_job = nil

-- TODO remove this, it's temporary to just take all text from context
-- and submit as the prompt
local function extract_text(context)
  local result = {}
  for _, entry in ipairs(context) do
    if entry.text then
      table.insert(result, entry.text)
    end
  end
  return table.concat(result, '\n')
end

-- This works but not so hot on the error handling lol
local function parse_anthropic_stream_completion(out)
  local body = out.body
  local lines = {}
  local text = ""

  for line in body:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local input_tokens = 0
  local output_tokens = 0

  for _, line in ipairs(lines) do
    if not line:match("^event:") then
      local stripped = line:gsub("^data: ", "")
      local data = vim.fn.json_decode(stripped)
      if data.type == "content_block_start" then
        text = text .. data.content_block.text
      elseif data.type == "content_block_delta" then
        text = text .. data.delta.text
      elseif data.type == 'message_start' then
        input_tokens = data.message.usage.input_tokens
      elseif data.type == 'message_delta' and data.delta.stop_reason == 'end_turn' then
        output_tokens = data.usage.output_tokens
      end
    end
  end

  return text, input_tokens, output_tokens
end

-- Generic configurable completion function
-- TODO DESIGN completion_config is for prompt and system, not needed here.
-- TODO service_config would be the config of the provided service
---@param service CompletionServiceConfig
M.completion = function(service, user_prompt, completion_config, is_stream, on_complete)
  local done = false
  local res = nil
  local succ = nil

  -- merging the history with the new prompt
  user_prompt = extract_text(user_prompt)

  log.debug('user prompt ' .. user_prompt)

  if M.current_job then
    M.current_job:shutdown()
    M.current_job = nil
  end

  local stream = nil
  local complete_callback = nil
  local error_callback = nil

  local stream_callback = function(error, chunk)
    log.debug('generic stream processing')
    if error then
      service.stream_error_cb(error)
      -- log.debug('received error in anthropic stream ' .. vim.inspect(error))
    else
      -- should do what is commented out below and call the cb
      local text = service.stream_cb(chunk)
      on_complete(text)
      -- local data_raw = string.match(chunk, "data: (.+)")

      -- if data_raw then
      --   local data = vim.json.decode(data_raw)

      --   local content = ''
      --   if data.delta and data.delta.text then
      --     content = data.delta.text
      --     log.debug('streaming ' .. content)
      --     on_complete(content)
      --   end
      -- end
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
      -- log.debug(vim.inspect(out))
      vim.schedule(function()
        local response_text, input_tokens, output_tokens = service.stream_complete_cb(out)
        log.debug('async callback token usage: ' ..
        input_tokens .. ' input tokens and ' .. output_tokens .. ' output tokens')
        vim.g.chatty_ai_last_input_tokens = input_tokens
        vim.g.chatty_ai_last_output_tokens = output_tokens
        -- TODO enable
        -- CONTEXT.append_entries({ { type = 'assistant', text = response_text } })
      end)
    end
  else
    -- Non streaming job config
    complete_callback = function(out)
      -- service.complete_cb(out, on_complete)
      log.debug('synchronous complete callback: ' .. tostring(out.status))
      if out and out.status == 200 then
        vim.schedule(function()
          local response = service.complete_cb(out)
          vim.g.chatty_ai_last_input_tokens = response.input_tokens
          vim.g.chatty_ai_last_output_tokens = response.output_tokens
          on_complete(response.content)
        end)
      end
    end
  end

  log.debug('service ' .. vim.inspect(service))
  local url, headers, body = service:configure_call(user_prompt, completion_config, is_stream)

  log.debug('url ' .. url)
  log.debug('headers ' .. vim.inspect(headers))
  log.debug('body ' .. vim.inspect(body))

  M.current_job = curl.post(url, {
    headers = headers,
    body = vim.fn.json_encode(body),
    stream = stream,
    callback = complete_callback,
    on_error = error_callback,
    raw = { '--no-buffer', '-s' },
  })

  log.debug('job started')
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
  -- TODO this should convert the context table into the anthropic messages format
  user_prompt = extract_text(user_prompt)

  log.debug('user prompt ' .. user_prompt)

  if M.current_job then
    M.current_job:shutdown()
    M.current_job = nil
  end

  local stream = nil
  local complete_callback = nil
  local error_callback = nil

  local stream_callback = function(error, chunk)
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
      log.debug('streaming complete callback')
      -- log.debug(vim.inspect(out))
      vim.schedule(function()
        -- TODO generic design for completion
        local response_text, input_tokens, output_tokens = parse_anthropic_stream_completion(out)
        log.debug('async callback token usage: ' ..
        input_tokens .. ' input tokens and ' .. output_tokens .. ' output tokens')
        vim.g.chatty_ai_last_input_tokens = input_tokens
        vim.g.chatty_ai_last_output_tokens = output_tokens
        CONTEXT.append_entries({ { type = 'assistant', text = response_text } })
      end)
    end
  else
    complete_callback = function(out)
      log.debug('synchronous complete callback: ' .. tostring(out.status))
      local content = nil
      if out and out.status == 200 then
        vim.schedule(function()
          local response = vim.fn.json_decode(out.body)
          -- log.debug(vim.inspect(out))
          -- Just for info until I figure out the design for token reporting
          log.debug('sync callback token usage: ' ..
          response.usage.input_tokens .. ' input tokens and ' .. response.usage.output_tokens .. ' output tokens')
          vim.g.chatty_ai_last_input_tokens = response.usage.input_tokens
          vim.g.chatty_ai_last_output_tokens = response.usage.output_tokens
          content = response.content
          if content[1].type == 'text' then
            CONTEXT.append_entries({ { type = 'assistant', text = content[1].text } })
            on_complete(content[1].text)
          else
            error('unexpected response type')
          end
        end)
      end
    end
  end

  local body = {
    stream = is_stream,
    model = 'claude-3-5-sonnet-20240620',   -- todo should be configurable
    messages = {
      {
        content = completion_config.prompt .. '\n' .. user_prompt,
        role = 'user',
      },
    },
    max_tokens = 4096,   -- todo configurable for each service
    system = completion_config.system,
    temperature = 1.0,   -- between 0.0 and 1.0 where higher is more creative
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

-- ChatGPT completion object (not streaming)
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
    model = 'gpt-4o',   -- todo config
    messages = {
      {
        content = completion_config.prompt .. '\n' .. user_prompt,
        role = 'user',
      },
    },
    max_tokens = 2000,   -- note 4096 is the max
    -- system = completion_config.system,
    temperature = 1.0,   -- between 0.0 and 1.0 where higher is more creative
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

---@param should_stream boolean
function M.completion_job(service, source_config, completion_config, target_config, should_stream)

  -- TODO at this point call something in targets that may take action based on the configuration
  -- For a hacky example let's erase the current selection if there is one
  -- it should generally just set things up for writing

  -- log.debug('service ' .. vim.inspect(service))
  -- local global_config = vim.g.chatty_ai_config.global
  -- log.debug('global config ' .. vim.inspect(global_config))
  -- log.debug('source config ' .. vim.inspect(source_config))
  -- log.debug('completion config ' .. vim.inspect(completion_config))
  -- log.debug('target config ' .. vim.inspect(target_config))

  -- When mode is streaming delete the visual selection and stream there
  -- TODO this is probably fine for both modes now
  if should_stream and util.is_visual_mode() then
    vim.api.nvim_command("normal! d")
  end

  -- Note that because sources can be async, we must treat them all as async. The
  -- completion job needs this partial function which will be called with the result
  -- of the execute sources call
  local target_cb = targets.get_callback(target_config)
  local completion_cb = function(prompt)
    -- TODO think about how prompts should be added. Just append, or insert, and handle de-duplication
    -- TODO should there be a context just in memory, a default context, lasting only for one execution?
    -- This would be when no context file is set
    CONTEXT.append_entries(prompt)

    -- local result =
    M.completion(service, prompt, completion_config, should_stream, target_cb)
    -- service_config.completion_fn(prompt, completion_config, service_config, should_stream, global_config, target_cb)
    -- M.anthropic_completion = function(user_prompt, completion_config, anthropic_config, is_stream, global_config, on_complete)
    -- M.completion = function(prompt, context, service, context, is_stream)
    -- if type(result) == 'string' and not should_stream then -- TODO get rid of this with final target implementation
    --   target_cb(result)
    -- end
  end

  sources.execute_sources(source_config, completion_cb)
end

return M
