local M = {}

local L = require('plenary.log')
local curl = require('plenary.curl')
local log = L.new({ plugin = 'chatty-ai' })
local config = require('chatty-ai.config')

local anthropic_completion_job = function(prompt)
  local url = 'https://webhook.site/d9b49699-0247-4c2f-b743-324171c63ae0'

  local loc = '/tmp/output.txt'
  local done = false
  local res = nil
  local succ = nil

  curl.post(url, {
    body = { prompt = prompt },
    output = loc,
    callback = function(out)
      vim.print('completion callback')
      done = true
      succ = out.status == 200 -- todo could be configurable
      res = out
    end,
  })

  vim.wait(config.current.global.timeout_ms, function()
    vim.print('completion done')
    return done
  end,
  20000)

  vim.print(res)
end

local completion_jobs = {
  anthropic = anthropic_completion_job,
}

function M.completion_job(prompt)
  completion_jobs[config.current.global.service](prompt)
end

return M
