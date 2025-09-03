-- lua/correctme/providers/ollama.lua
-- Ollama API implementation

local fn = vim.fn

local M = {}

-- Function to call Ollama API
function M.call(prompt, callback, config)
	local curl_cmd = string.format(
		"curl -s -X POST %s/api/generate -d %s",
		config.base_url,
		fn.shellescape(fn.json_encode({
			model = config.model,
			prompt = prompt,
			stream = false,
		}))
	)

	vim.fn.jobstart(curl_cmd, {
		on_stdout = function(_, data, _)
			local response = table.concat(data, "\n")
			local ok, result = pcall(fn.json_decode, response)
			if ok and result.response then
				callback(result.response)
			end
		end,
	})
end

return M