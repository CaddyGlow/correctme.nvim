-- lua/correctme/providers/openai.lua
-- OpenAI API implementation

local fn = vim.fn

local M = {}

-- Function to call OpenAI API
function M.call(prompt, callback, config)
	if not config.api_key then
		print(
			"OpenAI API key not found. Set "
				.. (config.env and config.env.api_key or "OPENAI_API_KEY")
				.. " environment variable."
		)
		return
	end

	local curl_cmd = string.format(
		"curl -s -X POST %s/chat/completions -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s",
		config.base_url,
		config.api_key,
		fn.shellescape(fn.json_encode({
			model = config.model,
			messages = { { role = "user", content = prompt } },
			max_tokens = config.max_tokens,
		}))
	)

	vim.fn.jobstart(curl_cmd, {
		on_stdout = function(_, data, _)
			local response = table.concat(data, "\n")
			local ok, result = pcall(fn.json_decode, response)
			if ok and result.choices and result.choices[1] and result.choices[1].message then
				callback(result.choices[1].message.content)
			end
		end,
	})
end

return M