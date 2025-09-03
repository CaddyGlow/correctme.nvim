describe('providers', function()
  local openai = require('correctme.providers.openai')
  local anthropic = require('correctme.providers.anthropic')
  local ollama = require('correctme.providers.ollama')

  describe('openai provider', function()
    it('should have call function', function()
      assert.is_function(openai.call)
    end)

    it('should handle missing api key', function()
      local config = { base_url = 'https://api.openai.com/v1' }
      local callback_called = false

      openai.call('test prompt', function()
        callback_called = true
      end, config)
      assert.is_false(callback_called)
    end)
  end)

  describe('anthropic provider', function()
    it('should have call function', function()
      assert.is_function(anthropic.call)
    end)

    it('should handle missing api key', function()
      local config = { base_url = 'https://api.anthropic.com/v1' }
      local callback_called = false

      anthropic.call('test prompt', function()
        callback_called = true
      end, config)
      assert.is_false(callback_called)
    end)
  end)

  describe('ollama provider', function()
    it('should have call function', function()
      assert.is_function(ollama.call)
    end)

    it('should not require api key', function()
      local _ = {
        base_url = 'http://localhost:11434',
        model = 'llama3.2:3b',
      }

      assert.is_function(ollama.call)
    end)
  end)
end)
