-- lua/correctme/preview.lua
-- Preview system for AI responses with accept/reject functionality

local M = {}

local api = vim.api

-- State for the preview system
local preview_state = {
  original_buf = nil,
  preview_buf = nil,
  preview_win = nil,
  original_text = nil,
  new_text = nil,
  start_line = nil,
  end_line = nil,
  prompt_type = nil,
}

-- Clear preview state
local function clear_preview_state()
  if preview_state.preview_win and api.nvim_win_is_valid(preview_state.preview_win) then
    api.nvim_win_close(preview_state.preview_win, true)
  end
  if preview_state.preview_buf and api.nvim_buf_is_valid(preview_state.preview_buf) then
    api.nvim_buf_delete(preview_state.preview_buf, { force = true })
  end

  preview_state = {
    original_buf = nil,
    preview_buf = nil,
    preview_win = nil,
    original_text = nil,
    new_text = nil,
    start_line = nil,
    end_line = nil,
    prompt_type = nil,
  }
end

-- Accept the changes
M.accept_changes = function()
  if not preview_state.original_buf or not preview_state.new_text then
    print('No preview to accept')
    return
  end

  -- Check if buffer is valid and modifiable
  if not api.nvim_buf_is_valid(preview_state.original_buf) then
    print('Original buffer is no longer valid')
    clear_preview_state()
    return
  end

  -- Temporarily make buffer modifiable if needed
  local was_modifiable = api.nvim_buf_get_option(preview_state.original_buf, 'modifiable')
  if not was_modifiable then
    api.nvim_buf_set_option(preview_state.original_buf, 'modifiable', true)
  end

  -- Apply changes to original buffer
  local success, err = pcall(function()
    local new_lines = vim.split(preview_state.new_text, '\n')
    api.nvim_buf_set_lines(
      preview_state.original_buf,
      preview_state.start_line,
      preview_state.end_line,
      false,
      new_lines
    )
  end)

  -- Restore original modifiable state
  if not was_modifiable then
    api.nvim_buf_set_option(preview_state.original_buf, 'modifiable', false)
  end

  if success then
    print('Changes accepted!')
  else
    print('Failed to apply changes: ' .. (err or 'unknown error'))
  end

  clear_preview_state()
end

-- Reject the changes
M.reject_changes = function()
  print('Changes rejected')
  clear_preview_state()
end

-- Show preview in a split window
M.show_preview = function(original_buf, original_text, new_text, start_line, end_line, prompt_type)
  -- Clear any existing preview first
  if M.is_preview_active() then
    clear_preview_state()
  end

  -- Store state
  preview_state.original_buf = original_buf
  preview_state.original_text = original_text
  preview_state.new_text = new_text
  preview_state.start_line = start_line
  preview_state.end_line = end_line
  preview_state.prompt_type = prompt_type

  -- Create preview buffer
  preview_state.preview_buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  api.nvim_buf_set_option(preview_state.preview_buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(preview_state.preview_buf, 'swapfile', false)
  api.nvim_buf_set_option(preview_state.preview_buf, 'bufhidden', 'wipe')

  -- Create content showing both original and new text
  local content = {}
  table.insert(content, '=== ORIGINAL ===')
  for _, line in ipairs(vim.split(original_text, '\n')) do
    table.insert(content, line)
  end
  table.insert(content, '')
  table.insert(content, '=== REWRITTEN (' .. string.upper(prompt_type) .. ') ===')
  for _, line in ipairs(vim.split(new_text, '\n')) do
    table.insert(content, line)
  end
  table.insert(content, '')
  table.insert(content, '=== COMMANDS ===')
  table.insert(content, ':LLMAcceptPreview  - Accept changes')
  table.insert(content, ':LLMRejectPreview  - Reject changes')
  table.insert(content, 'Press <q> to reject')

  -- Set buffer content
  api.nvim_buf_set_lines(preview_state.preview_buf, 0, -1, false, content)
  api.nvim_buf_set_option(preview_state.preview_buf, 'modifiable', false)

  -- Open split window
  vim.cmd('split')
  preview_state.preview_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(preview_state.preview_win, preview_state.preview_buf)

  -- Set window title
  api.nvim_win_set_option(preview_state.preview_win, 'winfixheight', true)

  -- Set buffer name for identification
  api.nvim_buf_set_name(preview_state.preview_buf, 'LLM Preview: ' .. prompt_type)

  -- Set up key mappings for the preview buffer
  local opts = { buffer = preview_state.preview_buf, noremap = true, silent = true }
  vim.keymap.set('n', 'q', M.reject_changes, opts)
  vim.keymap.set('n', '<CR>', M.accept_changes, opts)
  vim.keymap.set('n', 'y', M.accept_changes, opts)
  vim.keymap.set('n', 'n', M.reject_changes, opts)

  -- Add syntax highlighting for the sections
  vim.cmd('syntax match LLMPreviewHeader "^=== .* ===$"')
  vim.cmd('highlight LLMPreviewHeader guifg=#61AFEF gui=bold ctermfg=75 cterm=bold')

  print('Preview ready! Press <CR>/y to accept, q/n to reject')
end

-- Check if preview is active
M.is_preview_active = function()
  return preview_state.preview_buf ~= nil and api.nvim_buf_is_valid(preview_state.preview_buf)
end

return M
