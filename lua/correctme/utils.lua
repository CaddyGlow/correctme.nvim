-- lua/correctme/utils.lua
-- Utility functions for correctme.nvim

local M = {}

-- Generate a simple hash for content
function M.hash_content(text)
  local hash = 0
  for i = 1, #text do
    hash = (hash * 31 + string.byte(text, i)) % 2147483647
  end
  return hash
end

-- Split text into paragraphs
function M.split_paragraphs(text)
  local paragraphs = {}
  local current = ''

  for line in text:gmatch('[^\n]*') do
    if line == '' then
      if current ~= '' then
        table.insert(paragraphs, current)
        current = ''
      end
    else
      current = current .. (current == '' and '' or '\n') .. line
    end
  end

  if current ~= '' then
    table.insert(paragraphs, current)
  end

  return paragraphs
end

-- Build paragraph to line mapping for interactive mode
function M.build_paragraph_mapping(lines)
  local paragraph_to_line = {}
  local paragraphs = {}
  local current_paragraph = ''
  local paragraph_start_line = 1

  for line_num, line in ipairs(lines) do
    if line == '' then
      if current_paragraph ~= '' then
        table.insert(paragraphs, current_paragraph)
        paragraph_to_line[#paragraphs] = paragraph_start_line
        current_paragraph = ''
      end
      paragraph_start_line = line_num + 1
    else
      current_paragraph = current_paragraph .. (current_paragraph == '' and '' or '\n') .. line
    end
  end

  -- Add last paragraph if exists
  if current_paragraph ~= '' then
    table.insert(paragraphs, current_paragraph)
    paragraph_to_line[#paragraphs] = paragraph_start_line
  end

  return paragraphs, paragraph_to_line
end

-- Clean AI response to extract correction
function M.clean_correction(response)
  if not response or response:match('^Correct$') or response:match('^Correct%.') then
    return nil
  end

  if not response:match('Correction:') then
    return nil
  end

  -- Try to extract correction from response
  local correction = response:match('Correction:%s*(.+)')
  if not correction then
    return nil
  end

  -- Clean up the correction (remove extra explanations)
  correction = correction:match('^(.-)\n\nNote:') or correction
  correction = correction:match('^(.-)\n\n%(') or correction
  correction = correction:gsub('\n+', ' '):gsub('%s+', ' ')
  correction = vim.trim(correction)

  -- Clean up the correction more aggressively
  correction = correction:match('^(.-)\n\nExplanation') or correction
  correction = correction:match('^(.-)%. Explanation') or correction
  correction = correction:match('^(.-) Explanation') or correction
  correction = vim.trim(correction)

  return correction:len() > 0 and correction or nil
end

return M
