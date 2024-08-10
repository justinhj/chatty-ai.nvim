local M = {}

local L = require('plenary.log')
local curl = require('plenary.curl')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')
local sources = require('chatty-ai.sources')

local ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages'
local OPENAI_URL = 'https://api.openai.com/v1/chat/completions'

---@type Job
M.current_job = nil

-- TODO move to targets
local function write_string_at_cursor(str)
	local current_window = vim.api.nvim_get_current_win()
	local cursor_position = vim.api.nvim_win_get_cursor(current_window)
	local row, col = cursor_position[1], cursor_position[2]

	local lines = vim.split(str, "\n")
	vim.api.nvim_put(lines, "c", true, true)

	local num_lines = #lines
	local last_line_length = #lines[num_lines]
	vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })
end

local function process_data_lines(line, process_data)
	local json = line:match("^data: (.+)$")
	if json then
		local stop = false
		if json == "[DONE]" then
			return true
		end
		local data = vim.json.decode(json)
    stop = data.type == "message_stop"
		if stop then
			return true
		else
			vim.schedule(function()
				vim.cmd("undojoin") -- TODO what is this for
				process_data(data)
			end)
		end
	end
	return false
end

-- TODO fix up
local function process_anthropic_stream(error, data)
  if error then
    log.debug('received error ' .. vim.inspect(error))
  else

	-- process_data_lines(buffer, function(data)
	-- 	local content
    -- if data.delta and data.delta.text then
      -- content = data.delta.text
    -- end
	-- 	if content and content ~= vim.NIL then
	-- 		write_string_at_cursor(content)
	-- 	end
	-- end)
  end
end

---@param user_prompt string
---@param completion_config CompletionConfig
---@param anthropic_config AnthropicConfig
---@param is_stream boolean
local anthropic_completion_job = function(user_prompt, completion_config, anthropic_config, is_stream)
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
    stream = process_anthropic_stream

    error_callback = function(err)
      log.error('error callback' .. tostring(err))
      M.current_job = nil
    end

    complete_callback = function(out)
      log.debug('completed streaming callback ' .. tostring(out))

      vim.schedule(function()
        -- write_string_at_cursor(out)
        -- this is the full response from the job as a table with status, body, headers and exit
        -- note that headers is a table but body is escaped json

        vim.print(out)
      end)
    end
  else
    complete_callback = function(out)
      log.debug('completion sync callback ' .. vim.inspect(out))
      done = true
      succ = out.status == 200
      res = out
    end
  end

  local body = {
      stream = is_stream,
      model = 'claude-3-5-sonnet-20240620', -- todo config
      messages = {
        {
          content = completion_config.prompt .. '\n' .. user_prompt,
          role = 'user',
        },
      },
      max_tokens = 2000, -- note 4096 is the max
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

  if stream then
    log.debug('async return')
    return "async job lol" -- todo
  end

  vim.wait(config.current.global.timeout_ms, function()
    return done
  end,
  100) -- todo config interval and cancellation with key

  log.debug('done waiting ' .. tostring(succ) .. ' ' .. tostring(res ~= nil))

  local response = nil
  if succ and res then
    response = vim.fn.json_decode(res.body)
    local content = response.content
    if content[1].type == 'text' then
      return content[1].text
    end
  end
  return "error" -- todo error handling
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
local openai_completion_job = function(user_prompt, completion_config, openai_config, is_stream)
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

  vim.wait(config.current.global.timeout_ms, function()
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
---@type table<string, fun(user_prompt: string, completion_config: CompletionConfig, service_config: OpenAIConfig|AnthropicConfig, stream: boolean):string|Job>
local completion_jobs = {
  anthropic = anthropic_completion_job,
  openai = openai_completion_job,
}

--TODO should_stream should be part of a new config called target_config

---@param source_config_name string
---@param completion_config_name string
---@param should_stream boolean
function M.completion_job(source_config_name, completion_config_name, should_stream)
  local source_config = config.current.source_configs[source_config_name]
  if source_config == nil then
    log.error('source config not found: ' .. source_config_name)
    return
  end

  local completion_config = config.current.completion_configs[completion_config_name]
  if completion_config == nil then
    log.error('completion config not found for ' .. completion_config_name)
    return
  end

  local service = completion_config.service
  if service == nil then
    service = config.current.global.default_service
  end

  -- TODO response should be a table with some useful information such as token usage
  -- but for now a string is fine

  local service_config = config.current.services[service]

  -- Note that because sources can be async, we must treat them all as async. The 
  -- completion job needs this partial function which will be called with the result
  -- of the execute sources call

  local cb = function(prompt)
    local result = completion_jobs[service](prompt, completion_config, service_config, should_stream)
    if type(result) == 'string' and not should_stream then -- TODO get rid of this
      -- hard code a single output function, this can be configurable soon TODO
      write_string_at_cursor(result) -- TODO probably another callback
    end
  end

  sources.execute_sources(source_config, "", cb)
end

return M
