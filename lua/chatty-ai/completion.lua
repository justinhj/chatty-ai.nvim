local M = {}

local L = require('plenary.log')
local curl = require('plenary.curl')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')

local ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages'

local anthropic_completion_job = function(prompt)
  local loc = '/tmp/output.txt' -- todo
  local done = false
  local res = nil
  local succ = nil

  local body = {
      model = 'claude-3-5-sonnet-20240620', -- todo config
      messages = {
        {
          content = prompt,
          role = 'user',
        },
      },
      max_tokens = 2000, -- note 4096 is the max
      system = 'You are a brilliant software engineer that writes clear and simple code, but you should recommend optimizations or data structure changes if you see an opportunity. Your goal is to make the user happier because the code is so awesome and fit for purpose',
      temperature = 1.0, -- between 0.0 and 1.0 where higher is more creative
    }

  log.debug(body)

  curl.post(ANTHROPIC_URL, {
    headers = {
      ['x-api-key'] = config.current.anthropic.api_key_value,
      ['content-type'] = 'application/json',
      ['anthropic-version'] = config.current.anthropic.version,
    },
    body = vim.fn.json_encode(body),
    output = loc,
    callback = function(out)
      log.debug('completion callback')
      done = true
      succ = out.status == 200 -- todo config
      res = out
    end,
  })

  vim.wait(config.current.global.timeout_ms, function()
    return done
  end,
  20000) -- todo config

  log.debug(res)
end

-- Anthropic API errors
-- 400 - invalid_request_error: There was an issue with the format or content of your request. We may also use this error type for other 4XX status codes not listed below.
-- 401 - authentication_error: There’s an issue with your API key.
-- 403 - permission_error: Your API key does not have permission to use the specified resource.
-- 404 - not_found_error: The requested resource was not found.
-- 413 - request_too_large: Request exceeds the maximum allowed number of bytes.
-- 429 - rate_limit_error: Your account has hit a rate limit.
-- 500 - api_error: An unexpected error has occurred internal to Anthropic’s systems.
-- 529 - overloaded_error: Anthropic’s API is temporarily overloaded.

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

local completion_jobs = {
  anthropic = anthropic_completion_job,
}

function M.completion_job(prompt)
  completion_jobs[config.current.global.service](prompt)
end

return M
