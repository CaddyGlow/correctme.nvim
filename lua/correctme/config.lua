-- lua/correctme/config.lua
-- Configuration and defaults for correctme.nvim

local M = {}

M.default_config = {
  -- Current provider name
  provider = 'local-ollama',

  -- Provider configurations with type field and env var mappings
  providers = {
    ['local-ollama'] = {
      type = 'ollama',
      model = 'llama3.2:3b',
      api_key = nil,
      base_url = 'http://localhost:11434',
      max_tokens = 1000,
      env = {
        base_url = 'OLLAMA_BASE_URL',
        api_key = 'OLLAMA_API_KEY',
      },
    },
    ['gpt-3.5'] = {
      type = 'openai',
      model = 'gpt-3.5-turbo',
      api_key = nil,
      base_url = nil,
      max_tokens = 1000,
      env = {
        base_url = 'OPENAI_BASE_URL',
        api_key = 'OPENAI_API_KEY',
      },
    },
    ['gpt-4'] = {
      type = 'openai',
      model = 'gpt-4',
      api_key = nil,
      base_url = nil,
      max_tokens = 2000,
      env = {
        base_url = 'OPENAI_BASE_URL',
        api_key = 'OPENAI_API_KEY',
      },
    },
    ['gpt-4o'] = {
      type = 'openai',
      model = 'gpt-4o',
      api_key = nil,
      base_url = nil,
      max_tokens = 2000,
      env = {
        base_url = 'OPENAI_BASE_URL',
        api_key = 'OPENAI_API_KEY',
      },
    },
    ['claude-haiku'] = {
      type = 'anthropic',
      model = 'claude-3-5-haiku-20241022',
      api_key = nil,
      base_url = nil,
      max_tokens = 1000,
      env = {
        base_url = 'ANTHROPIC_BASE_URL',
        api_key = 'ANTHROPIC_API_KEY',
      },
    },
    ['claude-sonnet'] = {
      type = 'anthropic',
      model = 'claude-sonnet-4-20250514',
      api_key = nil,
      base_url = nil,
      max_tokens = 2000,
      env = {
        base_url = 'ANTHROPIC_BASE_URL',
        api_key = 'ANTHROPIC_API_KEY',
      },
    },
  },

  -- Default values for provider types when config values are nil
  defaults = {
    openai = {
      base_url = 'https://api.openai.com/v1',
    },
    anthropic = {
      base_url = 'https://api.anthropic.com/v1',
    },
    ollama = {
      base_url = 'http://localhost:11434',
    },
  },

  -- Prompts
  prompts = {
    proofreading = [[Proofread the following message in American English. If it is grammatically correct, ]]
      .. [[just respond with the word "Correct". ]]
      .. [[If it is grammatically incorrect or has spelling mistakes, respond with "Correction: ", ]]
      .. [[followed by the corrected version.
{text}]],
    rewrite = [[Rewrite the following text for clarity in its original language. ]]
      .. [[Keep the same meaning but improve readability. Respond with ONLY the improved text:
{text}]],
    proofread = [[Proofread and correct the following text. Fix any grammar, spelling, or punctuation errors. ]]
      .. [[Respond with ONLY the corrected text:
{text}]],
    rephrase = [[Rephrase the following text while keeping the same meaning. ]]
      .. [[Use different words and sentence structure. Respond with ONLY the rephrased text:
{text}]],
    professional = [[Rewrite the following text in a professional, formal tone suitable for business communication. ]]
      .. [[Maintain the original meaning but make it more polished and professional. ]]
      .. [[Respond with ONLY the rewritten text:
{text}]],
    friendly = [[Rewrite the following text in a friendly, casual tone that feels warm and approachable. ]]
      .. [[Keep the same meaning but make it sound more conversational and friendly. ]]
      .. [[Respond with ONLY the rewritten text:
{text}]],
    emojify = [[Rewrite the following text by adding appropriate emojis to make it more expressive and engaging. ]]
      .. [[Keep the original meaning and tone but enhance it with relevant emojis. ]]
      .. [[Respond with ONLY the text with emojis:
{text}]],
    elaborate = [[Expand and elaborate on the following text. Add more detail, context, and explanation ]]
      .. [[while maintaining the original meaning and tone. Respond with ONLY the expanded text:
{text}]],
    shorten = [[Shorten the following text while keeping the essential meaning and key points. ]]
      .. [[Make it more concise and to the point. Respond with ONLY the shortened text:
{text}]],
    synonyms = [[Give up to 5 synonyms for the expression "{expression}". ]]
      .. [[Just respond with the synonyms, separated by newlines.]],
  },

  -- Check interval in milliseconds
  check_interval = 5000,

  -- Preview mode: 'buffer' or 'inline'
  preview_mode = 'inline',
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

  -- Apply defaults for any remaining nil fields
  for field, default_value in pairs(provider_defaults) do
    if resolved[field] == nil then
      resolved[field] = default_value
    end
  end

  return resolved
end

-- Setup function to merge user config with defaults
function M.get_config(opts)
  return vim.tbl_deep_extend('force', M.default_config, opts or {})
end

return M
