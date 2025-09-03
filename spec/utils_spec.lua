describe('utils', function()
  local utils = require('correctme.utils')

  describe('hash_content', function()
    it('should generate consistent hash for same text', function()
      local text = 'Hello, world!'
      local hash1 = utils.hash_content(text)
      local hash2 = utils.hash_content(text)

      assert.equals(hash1, hash2)
    end)

    it('should generate different hashes for different text', function()
      local hash1 = utils.hash_content('Hello')
      local hash2 = utils.hash_content('World')

      assert.is_not_equals(hash1, hash2)
    end)
  end)

  describe('split_paragraphs', function()
    it('should split single paragraph', function()
      local text = 'This is a single paragraph.'
      local paragraphs = utils.split_paragraphs(text)

      assert.equals(1, #paragraphs)
      assert.equals('This is a single paragraph.', paragraphs[1])
    end)

    it('should split multiple paragraphs', function()
      local text = 'First paragraph.\n\nSecond paragraph.'
      local paragraphs = utils.split_paragraphs(text)

      assert.equals(2, #paragraphs)
      assert.equals('First paragraph.', paragraphs[1])
      assert.equals('Second paragraph.', paragraphs[2])
    end)

    it('should handle empty text', function()
      local paragraphs = utils.split_paragraphs('')
      assert.equals(0, #paragraphs)
    end)
  end)

  describe('clean_correction', function()
    it("should return nil for 'Correct' response", function()
      local result = utils.clean_correction('Correct')
      assert.is_nil(result)
    end)

    it('should extract correction from valid response', function()
      local response = 'Correction: This is the corrected text.'
      local result = utils.clean_correction(response)

      assert.equals('This is the corrected text.', result)
    end)

    it('should clean correction with explanation', function()
      local response = 'Correction: This is corrected text. Explanation: Grammar was wrong.'
      local result = utils.clean_correction(response)

      assert.equals('This is corrected text.', result)
    end)

    it('should return nil for response without correction', function()
      local response = 'This text looks fine to me.'
      local result = utils.clean_correction(response)

      assert.is_nil(result)
    end)

    it('should handle correction with note', function()
      local response = 'Correction: Fixed text here.\n\nNote: Changed grammar.'
      local result = utils.clean_correction(response)

      assert.equals('Fixed text here.', result)
    end)
  end)

  describe('build_paragraph_mapping', function()
    it('should map paragraphs to line numbers', function()
      local lines = { 'First line', '', 'Third line', 'Fourth line' }
      local paragraphs, mapping = utils.build_paragraph_mapping(lines)

      assert.equals(2, #paragraphs)
      assert.equals('First line', paragraphs[1])
      assert.equals('Third line\nFourth line', paragraphs[2])
      assert.equals(1, mapping[1])
      assert.equals(3, mapping[2])
    end)
  end)
end)
