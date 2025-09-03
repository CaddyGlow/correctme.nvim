describe('response parsing', function()
  local fn = vim.fn

  describe('openai response parsing', function()
    it('should parse valid response', function()
      local response = {
        choices = {
          {
            message = {
              content = 'This is a test response',
            },
          },
        },
      }

      local json_str = fn.json_encode(response)
      local ok, result = pcall(fn.json_decode, json_str)

      assert.is_true(ok)
      assert.is_table(result.choices)
      assert.equals('This is a test response', result.choices[1].message.content)
    end)

    it('should handle malformed response', function()
      local invalid_json = 'invalid json'
      local ok, _ = pcall(fn.json_decode, invalid_json)

      assert.is_false(ok)
    end)
  end)

  describe('anthropic response parsing', function()
    it('should parse valid response', function()
      local response = {
        content = {
          {
            text = 'This is an anthropic response',
          },
        },
      }

      local json_str = fn.json_encode(response)
      local ok, result = pcall(fn.json_decode, json_str)

      assert.is_true(ok)
      assert.is_table(result.content)
      assert.equals('This is an anthropic response', result.content[1].text)
    end)
  end)

  describe('ollama response parsing', function()
    it('should parse valid response', function()
      local response = {
        response = 'This is an ollama response',
        done = true,
      }

      local json_str = fn.json_encode(response)
      local ok, result = pcall(fn.json_decode, json_str)

      assert.is_true(ok)
      assert.equals('This is an ollama response', result.response)
      assert.is_true(result.done)
    end)
  end)
end)
