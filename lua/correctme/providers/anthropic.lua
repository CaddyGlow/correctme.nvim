-- lua/correctme/providers/anthropic.lua
-- Anthropic API implementation

local fn = vim.fn

local M = {}

-- Function to call Anthropic API
function M.call(prompt, callback, config)
  if not config.api_key then
    print(
      'Anthropic API key not found. Set '
        .. (config.env and config.env.api_key or 'ANTHROPIC_API_KEY')
        .. ' environment variable.'
    )
    return
  end

  local curl_cmd = string.format(
    "curl -s -X POST %s/messages -H 'x-api-key: %s' -H 'Content-Type: application/json' -H 'anthropic-version: 2023-06-01' -d %s",
    config.base_url,
    config.api_key,
    fn.shellescape(fn.json_encode({
      model = config.model,
      max_tokens = config.max_tokens,
      messages = { { role = 'user', content = prompt } },
    }))
  )

  vim.fn.jobstart(curl_cmd, {
    on_stdout = function(_, data, _)
      local response = table.concat(data, '\n')
      local ok, result = pcall(fn.json_decode, response)
      if ok and result.content and result.content[1] and result.content[1].text then
        callback(result.content[1].text)
      end
    end,
  })
end

return M
