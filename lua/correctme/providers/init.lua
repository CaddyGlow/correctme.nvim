-- lua/correctme/providers/init.lua
-- Provider resolution and routing

local openai = require("correctme.providers.openai")
local anthropic = require("correctme.providers.anthropic")  
local ollama = require("correctme.providers.ollama")
local config = require("correctme.config")
local statusline = require("correctme.statusline")

local M = {}

-- Unified function to call the configured AI provider
function M.call_ai_provider(prompt, callback, provider_name, providers, defaults)
	local provider_config = providers[provider_name]
	if not provider_config then
		print("Provider '" .. provider_name .. "' not found in configuration")
		return
	end

	-- Resolve configuration with environment variables and defaults
	local resolved_config = config.resolve_provider_config(provider_config, defaults)

	-- Start query tracking
	statusline.start_query()

	-- Wrap callback to track query completion
	local wrapped_callback = function(response)
		statusline.end_query()
		callback(response)
	end

	if resolved_config.type == "openai" then
		openai.call(prompt, wrapped_callback, resolved_config)
	elseif resolved_config.type == "anthropic" then
		anthropic.call(prompt, wrapped_callback, resolved_config)
	elseif resolved_config.type == "ollama" then
		ollama.call(prompt, wrapped_callback, resolved_config)
	else
		statusline.end_query() -- End query on error
		print("Unknown provider type: " .. tostring(resolved_config.type))
	end
end

return M