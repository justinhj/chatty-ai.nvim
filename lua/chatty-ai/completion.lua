local M = {}

local L = require('plenary.log')
local curl = require('plenary.curl')
local log = L.new({ plugin = 'chatty-ai' })
local sources = require('chatty-ai.sources')
local targets = require('chatty-ai.targets')
local util = require('chatty-ai.util')
local CONTEXT = require('chatty-ai.context')

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

-- Generic configurable completion function
---@param service CompletionServiceConfig
M.completion = function(service, user_prompt, completion_config, is_stream, on_complete)
  local done = false
  local res = nil
  local succ = nil

  -- TODO merging the context and history with the new prompt
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
    else
      local text = service.stream_cb(chunk)
      on_complete(text)
    end
  end

  if is_stream then
    stream = vim.schedule_wrap(stream_callback)

    error_callback = function(err)
      log.error('error callback' .. tostring(err))
      M.current_job = nil
    end

    complete_callback = function(out)
      log.debug('streaming complete callback')
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
      log.debug('synchronous complete callback: ' .. tostring(out.status))
      if out and out.status == 200 then
        vim.schedule(function()
          local response = service.complete_cb(out)
          vim.g.chatty_ai_last_input_tokens = response.input_tokens
          vim.g.chatty_ai_last_output_tokens = response.output_tokens
          on_complete(response.content)
        end)
      else
        log.error('Completion failed with status ' .. tostring(out.status))
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
  end

  sources.execute_sources(source_config, completion_cb)
end

return M
