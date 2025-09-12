-- lua/correctme/diff_preview.lua
-- Enhanced diff preview system using gitsigns-style visualization

local M = {}

local api = vim.api

-- State for the diff preview system
local diff_state = {
  original_buf = nil,
  preview_buf = nil,
  preview_win = nil,
  original_text = nil,
  new_text = nil,
  start_line = nil,
  end_line = nil,
  prompt_type = nil,
  diff_extmarks = {},
}

-- Namespace for diff highlighting
local diff_ns = api.nvim_create_namespace('correctme_diff_preview')

-- Define highlight groups for diff visualization
local function setup_highlights()
  -- Define diff highlight groups similar to gitsigns
  vim.cmd([[
    highlight default CorrectmeDiffAdd guibg=#22863a guifg=#ffffff ctermbg=22 ctermfg=15
    highlight default CorrectmeDiffDelete guibg=#d73a49 guifg=#ffffff ctermbg=52 ctermfg=15
    highlight default CorrectmeDiffChange guibg=#b08800 guifg=#ffffff ctermbg=58 ctermfg=15
    highlight default CorrectmeDiffText guibg=#e1c542 guifg=#000000 ctermbg=11 ctermfg=0
    highlight default CorrectmePreviewHeader guifg=#61AFEF gui=bold ctermfg=75 cterm=bold
    highlight default CorrectmePreviewSection guifg=#98c379 gui=bold ctermfg=114 cterm=bold
  ]])
end

-- Clear diff state and extmarks
local function clear_diff_state()
  if diff_state.preview_win and api.nvim_win_is_valid(diff_state.preview_win) then
    api.nvim_win_close(diff_state.preview_win, true)
  end
  if diff_state.preview_buf and api.nvim_buf_is_valid(diff_state.preview_buf) then
    api.nvim_buf_delete(diff_state.preview_buf, { force = true })
  end

  -- Clear extmarks
  if diff_state.original_buf and api.nvim_buf_is_valid(diff_state.original_buf) then
    api.nvim_buf_clear_namespace(diff_state.original_buf, diff_ns, 0, -1)
  end

  diff_state = {
    original_buf = nil,
    preview_buf = nil,
    preview_win = nil,
    original_text = nil,
    new_text = nil,
    start_line = nil,
    end_line = nil,
    prompt_type = nil,
    diff_extmarks = {},
  }
end

-- Calculate diff lines using Vim's diff functionality
local function calculate_diff(original_lines, new_lines)
  -- Create temporary buffers for diff calculation
  local temp_buf1 = api.nvim_create_buf(false, true)
  local temp_buf2 = api.nvim_create_buf(false, true)

  api.nvim_buf_set_lines(temp_buf1, 0, -1, false, original_lines)
  api.nvim_buf_set_lines(temp_buf2, 0, -1, false, new_lines)

  -- Use vim's internal diff algorithm
  local original_diff = {}
  local new_diff = {}

  -- Simple line-by-line comparison
  local max_lines = math.max(#original_lines, #new_lines)
  for i = 1, max_lines do
    local orig_line = original_lines[i] or ''
    local new_line = new_lines[i] or ''

    if orig_line ~= new_line then
      if original_lines[i] then
        table.insert(original_diff, { line = i, type = 'delete', text = orig_line })
      end
      if new_lines[i] then
        table.insert(new_diff, { line = i, type = 'add', text = new_line })
      end
    else
      table.insert(original_diff, { line = i, type = 'context', text = orig_line })
      table.insert(new_diff, { line = i, type = 'context', text = new_line })
    end
  end

  -- Clean up temp buffers
  api.nvim_buf_delete(temp_buf1, { force = true })
  api.nvim_buf_delete(temp_buf2, { force = true })

  return original_diff, new_diff
end

-- Accept the changes
M.accept_changes = function()
  if not diff_state.original_buf or not diff_state.new_text then
    print('No preview to accept')
    return
  end

  -- Check if buffer is valid and modifiable
  if not api.nvim_buf_is_valid(diff_state.original_buf) then
    print('Original buffer is no longer valid')
    clear_diff_state()
    return
  end

  -- Temporarily make buffer modifiable if needed
  local was_modifiable = api.nvim_buf_get_option(diff_state.original_buf, 'modifiable')
  if not was_modifiable then
    api.nvim_buf_set_option(diff_state.original_buf, 'modifiable', true)
  end

  -- Apply changes to original buffer
  local success, err = pcall(function()
    local new_lines = vim.split(diff_state.new_text, '\n')
    api.nvim_buf_set_lines(
      diff_state.original_buf,
      diff_state.start_line,
      diff_state.end_line,
      false,
      new_lines
    )
  end)

  -- Restore original modifiable state
  if not was_modifiable then
    api.nvim_buf_set_option(diff_state.original_buf, 'modifiable', false)
  end

  if success then
    print('Changes accepted!')
  else
    print('Failed to apply changes: ' .. (err or 'unknown error'))
  end

  clear_diff_state()
end

-- Reject the changes
M.reject_changes = function()
  print('Changes rejected')
  clear_diff_state()
end

-- Show enhanced diff preview with gitsigns-style highlighting
M.show_diff_preview = function(
  original_buf,
  original_text,
  new_text,
  start_line,
  end_line,
  prompt_type
)
  -- Setup highlights first
  setup_highlights()

  -- Clear any existing preview first
  if M.is_preview_active() then
    clear_diff_state()
  end

  -- Store state
  diff_state.original_buf = original_buf
  diff_state.original_text = original_text
  diff_state.new_text = new_text
  diff_state.start_line = start_line
  diff_state.end_line = end_line
  diff_state.prompt_type = prompt_type

  -- Split texts into lines
  local original_lines = vim.split(original_text, '\n')
  local new_lines = vim.split(new_text, '\n')

  -- Calculate diff
  calculate_diff(original_lines, new_lines)

  -- Create preview buffer
  diff_state.preview_buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  api.nvim_buf_set_option(diff_state.preview_buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(diff_state.preview_buf, 'swapfile', false)
  api.nvim_buf_set_option(diff_state.preview_buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(diff_state.preview_buf, 'filetype', 'diff')

  -- Create side-by-side diff content
  local content = {}
  local max_lines = math.max(#original_lines, #new_lines)

  -- Header
  table.insert(
    content,
    '┌─ ORIGINAL ─────────────────────┬─ REWRITTEN ('
      .. string.upper(prompt_type)
      .. ') ─────────────────┐'
  )

  for i = 1, max_lines do
    local orig_line = original_lines[i] or ''
    local new_line = new_lines[i] or ''
    local orig_status = '  '
    local new_status = '  '

    -- Determine diff status
    if orig_line ~= new_line then
      if orig_line ~= '' and new_line ~= '' then
        orig_status = '~ '
        new_status = '~ '
      elseif orig_line == '' then
        new_status = '+ '
      elseif new_line == '' then
        orig_status = '- '
      else
        orig_status = '- '
        new_status = '+ '
      end
    end

    -- Format side-by-side with proper padding
    local left_part = orig_status .. string.sub(orig_line, 1, 28)
    left_part = left_part .. string.rep(' ', 31 - #left_part)
    local right_part = new_status .. new_line

    table.insert(content, '│' .. left_part .. '│ ' .. right_part)
  end

  table.insert(
    content,
    '└────────────────────────────────┴─────────────────────────────────────────┘'
  )
  table.insert(content, '')
  table.insert(content, '󰌃 Commands:')
  table.insert(content, '  <CR> / y  Accept changes')
  table.insert(content, '  q / n     Reject changes')
  table.insert(content, '  :LLMAcceptPreview  :LLMRejectPreview')

  -- Set buffer content
  api.nvim_buf_set_lines(diff_state.preview_buf, 0, -1, false, content)
  api.nvim_buf_set_option(diff_state.preview_buf, 'modifiable', false)

  -- Apply syntax highlighting
  vim.cmd('syntax match CorrectmePreviewHeader "^┌.*┐$"')
  vim.cmd('syntax match CorrectmePreviewHeader "^└.*┘$"')
  vim.cmd('syntax match CorrectmePreviewSection "^󰌃.*:$"')
  vim.cmd('syntax match CorrectmeDiffAdd "^│.*│ + .*"')
  vim.cmd('syntax match CorrectmeDiffDelete "^│.* - .*│"')
  vim.cmd('syntax match CorrectmeDiffChange "^│.* \\~ .*│.*\\~ .*"')

  -- Open split window
  vim.cmd('split')
  diff_state.preview_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(diff_state.preview_win, diff_state.preview_buf)

  -- Set window title
  api.nvim_win_set_option(diff_state.preview_win, 'winfixheight', true)
  api.nvim_buf_set_name(diff_state.preview_buf, 'LLM Diff Preview: ' .. prompt_type)

  -- Set up key mappings for the preview buffer
  local opts = { buffer = diff_state.preview_buf, noremap = true, silent = true }
  vim.keymap.set('n', 'q', M.reject_changes, opts)
  vim.keymap.set('n', '<CR>', M.accept_changes, opts)
  vim.keymap.set('n', 'y', M.accept_changes, opts)
  vim.keymap.set('n', 'n', M.reject_changes, opts)

  print('Enhanced diff preview ready! Press <CR>/y to accept, q/n to reject')
end

-- Check if preview is active
M.is_preview_active = function()
  return diff_state.preview_buf ~= nil and api.nvim_buf_is_valid(diff_state.preview_buf)
end

return M
