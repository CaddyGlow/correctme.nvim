describe('correctme', function()
  local correctme = require('correctme')

  describe('setup', function()
    it('should setup without errors', function()
      assert.is_function(correctme.setup)
      correctme.setup({})
    end)
  end)

  describe('public interface', function()
    before_each(function()
      correctme.setup({})
    end)

    it('should have check_document function', function()
      assert.is_function(correctme.check_document)
    end)

    it('should have check_document_diff function', function()
      assert.is_function(correctme.check_document_diff)
    end)

    it('should have start_checking function', function()
      assert.is_function(correctme.start_checking)
    end)

    it('should have stop_checking function', function()
      assert.is_function(correctme.stop_checking)
    end)

    it('should have rewrite_selection function', function()
      assert.is_function(correctme.rewrite_selection)
    end)

    it('should have accept_suggestion function', function()
      assert.is_function(correctme.accept_suggestion)
    end)

    it('should have get_synonyms function', function()
      assert.is_function(correctme.get_synonyms)
    end)

    it('should have statusline function', function()
      assert.is_function(correctme.statusline)
      local result = correctme.statusline()
      assert.is_string(result)
    end)
  end)
end)
