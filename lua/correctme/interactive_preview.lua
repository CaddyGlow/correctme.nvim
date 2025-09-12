-- lua/correctme/interactive_preview.lua
-- Special preview system for interactive mode showing original text on top and correction below

local M = {}

local api = vim.api

-- State for interactive preview
local preview_state = {
  preview_buf = nil,
  preview_win = nil,
  original_text = nil,
  new_text = nil,
  prompt_type = nil,
}

-- Clear interactive preview state
local function clear_preview_state()
  if preview_state.preview_win and api.nvim_win_is_valid(preview_state.preview_win) then
    api.nvim_win_close(preview_state.preview_win, true)
  end
  if preview_state.preview_buf and api.nvim_buf_is_valid(preview_state.preview_buf) then
    api.nvim_buf_delete(preview_state.preview_buf, { force = true })
  end

  preview_state = {
    preview_buf = nil,
    preview_win = nil,
    original_text = nil,
    new_text = nil,
    prompt_type = nil,
  }
end

-- Show interactive preview with original on top, correction below
M.show_interactive_preview = function(original_text, new_text, prompt_type, suggestion_info)
  -- Clear any existing preview first
  clear_preview_state()

  -- Store state
  preview_state.original_text = original_text
  preview_state.new_text = new_text
  preview_state.prompt_type = prompt_type

  -- Create preview buffer
  preview_state.preview_buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  api.nvim_buf_set_option(preview_state.preview_buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(preview_state.preview_buf, 'swapfile', false)
  api.nvim_buf_set_option(preview_state.preview_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(preview_state.preview_buf, 'filetype', 'diff')

  -- Create vertical layout content (original on top, correction below)
  local content = {}
  local header = string.format('=== INTERACTIVE SUGGESTION %s ===', suggestion_info or '')
  table.insert(content, header)
  table.insert(content, '')

  -- Original text section
  table.insert(
    content,
    '┌─ ORIGINAL ─────────────────────────────────────────────────────────────────┐'
  )
  for _, line in ipairs(vim.split(original_text, '\n')) do
    table.insert(content, '│ ' .. line .. string.rep(' ', math.max(0, 77 - #line)) .. '│')
  end
  table.insert(
    content,
    '└────────────────────────────────────────────────────────────────────────────┘'
  )
  table.insert(content, '')

  -- Correction section
  table.insert(
    content,
    '┌─ SUGGESTED CORRECTION ────────────────────────────────────────────────────┐'
  )
  for _, line in ipairs(vim.split(new_text, '\n')) do
    table.insert(content, '│ ' .. line .. string.rep(' ', math.max(0, 77 - #line)) .. '│')
  end
  table.insert(
    content,
    '└────────────────────────────────────────────────────────────────────────────┘'
  )
  table.insert(content, '')

  -- Instructions
  table.insert(
    content,
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  )
  table.insert(content, '  Press: y = Accept  •  n = Skip  •  q = Quit interactive mode')
  table.insert(
    content,
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  )

  -- Set buffer content
  api.nvim_buf_set_lines(preview_state.preview_buf, 0, -1, false, content)
  api.nvim_buf_set_option(preview_state.preview_buf, 'modifiable', false)

  -- Apply syntax highlighting
  vim.cmd('syntax match InteractiveHeader "^=== .* ===$"')
  vim.cmd('syntax match InteractiveOriginalBox "^┌─ ORIGINAL .*┐$"')
  vim.cmd('syntax match InteractiveOriginalBox "^└─.*─┘$"')
  vim.cmd('syntax match InteractiveCorrectionBox "^┌─ SUGGESTED CORRECTION .*┐$"')
  vim.cmd('syntax match InteractiveCorrectionBox "^└─.*─┘$"')
  vim.cmd('syntax match InteractiveInstructions "^━.*━$"')
  vim.cmd('syntax match InteractiveInstructions "Press:.*mode$"')

  -- Set up highlight groups
  vim.cmd([[
    highlight InteractiveHeader guifg=#61AFEF gui=bold ctermfg=75 cterm=bold
    highlight InteractiveOriginalBox guifg=#e06c75 gui=bold ctermfg=204 cterm=bold
    highlight InteractiveCorrectionBox guifg=#98c379 gui=bold ctermfg=114 cterm=bold
    highlight InteractiveInstructions guifg=#c678dd gui=italic ctermfg=176 cterm=italic
  ]])

  -- Open horizontal split window (original on top, correction below)
  vim.cmd('split')
  preview_state.preview_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(preview_state.preview_win, preview_state.preview_buf)

  -- Size the window appropriately
  api.nvim_win_set_height(preview_state.preview_win, math.min(#content + 2, 20))
  api.nvim_win_set_option(preview_state.preview_win, 'winfixheight', true)

  -- Set buffer name for identification
  api.nvim_buf_set_name(
    preview_state.preview_buf,
    'Interactive Preview: ' .. (prompt_type or 'suggestion')
  )
end

-- Close interactive preview
M.close_preview = function()
  clear_preview_state()
end

-- Check if preview is active
M.is_preview_active = function()
  return preview_state.preview_buf ~= nil and api.nvim_buf_is_valid(preview_state.preview_buf)
end

return M
