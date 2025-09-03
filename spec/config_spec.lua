describe("config", function()
  local config = require("correctme.config")
  
  describe("get_config", function()
    it("should return default config when no opts provided", function()
      local result = config.get_config()
      assert.is_table(result)
      assert.equals("local-ollama", result.provider)
    end)
    
    it("should merge user options with defaults", function()
      local result = config.get_config({ provider = "gpt-4" })
      assert.equals("gpt-4", result.provider)
      assert.is_table(result.providers)
    end)
  end)
  
  describe("resolve_provider_config", function()
    it("should resolve provider config with defaults", function()
      local provider_config = { type = "openai", api_key = nil, env = { api_key = "TEST_KEY" } }
      local defaults = { openai = { base_url = "https://api.openai.com/v1" } }
      
      local result = config.resolve_provider_config(provider_config, defaults)
      assert.is_table(result)
      assert.equals("https://api.openai.com/v1", result.base_url)
    end)
  end)
end)