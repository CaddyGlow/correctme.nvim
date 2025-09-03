-- lua/correctme/config.lua
-- Configuration and defaults for correctme.nvim

local M = {}

M.default_config = {
	-- Current provider name
	provider = "local-ollama",

	-- Provider configurations with type field and env var mappings
	providers = {
		["local-ollama"] = {
			type = "ollama",
			model = "llama3.2:3b",
			api_key = nil,
			base_url = "http://localhost:11434",
			max_tokens = 1000,
			env = {
				base_url = "OLLAMA_BASE_URL",
				api_key = "OLLAMA_API_KEY",
			},
		},
		["gpt-3.5"] = {
			type = "openai",
			model = "gpt-3.5-turbo",
			api_key = nil,
			base_url = nil,
			max_tokens = 1000,
			env = {
				base_url = "OPENAI_BASE_URL",
				api_key = "OPENAI_API_KEY",
			},
		},
		["gpt-4"] = {
			type = "openai",
			model = "gpt-4",
			api_key = nil,
			base_url = nil,
			max_tokens = 2000,
			env = {
				base_url = "OPENAI_BASE_URL",
				api_key = "OPENAI_API_KEY",
			},
		},
		["claude-haiku"] = {
			type = "anthropic",
			model = "claude-3-haiku-20240307",
			api_key = nil,
			base_url = nil,
			max_tokens = 1000,
			env = {
				base_url = "ANTHROPIC_BASE_URL",
				api_key = "ANTHROPIC_API_KEY",
			},
		},
		["claude-sonnet"] = {
			type = "anthropic",
			model = "claude-3-sonnet-20240229",
			api_key = nil,
			base_url = nil,
			max_tokens = 2000,
			env = {
				base_url = "ANTHROPIC_BASE_URL",
				api_key = "ANTHROPIC_API_KEY",
			},
		},
	},

	-- Default values for provider types when config values are nil
	defaults = {
		openai = {
			base_url = "https://api.openai.com/v1",
		},
		anthropic = {
			base_url = "https://api.anthropic.com/v1",
		},
		ollama = {
			base_url = "http://localhost:11434",
		},
	},

	-- Prompts
	prompts = {
		proofreading = [[Proofread the following message in American English. If it is grammatically correct, just respond with the word "Correct". If it is grammatically incorrect or has spelling mistakes, respond with "Correction: ", followed by the corrected version.
{text}]],
		rewrite = [[Rewrite the following text for clarity in its original language. Keep the same meaning but improve readability. Respond with ONLY the improved text:
{text}]],
		synonyms = [[Give up to 5 synonyms for the expression "{expression}". Just respond with the synonyms, separated by newlines.]],
	},

	-- Check interval in milliseconds
	check_interval = 5000,
}

-- Resolve provider configuration with environment variable fallback
function M.resolve_provider_config(provider_config, defaults)
	local resolved = vim.deepcopy(provider_config)
	local provider_defaults = defaults[provider_config.type] or {}

	-- Resolve each field with env var fallback, then defaults
	for field, env_var in pairs(provider_config.env or {}) do
		if resolved[field] == nil then
			-- Try environment variable first
			resolved[field] = os.getenv(env_var)
			-- Fall back to defaults if still nil
			if resolved[field] == nil and provider_defaults[field] then
				resolved[field] = provider_defaults[field]
			end
		end
	end

	return resolved
end

-- Setup function to merge user config with defaults
function M.get_config(opts)
	return vim.tbl_deep_extend("force", M.default_config, opts or {})
end

return M