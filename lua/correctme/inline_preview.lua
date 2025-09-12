-- lua/correctme/inline_preview.lua
-- Inline preview system using gitsigns' preview_hunk_inline functionality

local M = {}

local api = vim.api

-- State for inline preview
local inline_state = {
  original_buf = nil,
  original_text = nil,
  new_text = nil,
  start_line = nil,
  end_line = nil,
  prompt_type = nil,
  temp_file = nil,
  has_gitsigns = false,
}

-- Setup highlight groups for inline diff
local function setup_inline_highlights()
  -- Define our own highlight groups that fallback to diff colors
  vim.cmd([[
    highlight default link CorrectmeInlineAdd GitSignsAdd
    highlight default link CorrectmeInlineDelete GitSignsDelete
    highlight default link CorrectmeInlineChange GitSignsChange
    " Fallback if GitSigns highlights don't exist
    highlight default CorrectmeInlineAdd guifg=#28a745 guibg=#f0fff4 ctermfg=2 ctermbg=22
    highlight default CorrectmeInlineDelete guifg=#d73a49 guibg=#ffeef0 ctermfg=1 ctermbg=52
    highlight default CorrectmeInlineChange guifg=#b08800 guibg=#fff8c5 ctermfg=3 ctermbg=58
  ]])
end

-- Clear inline preview state
local function clear_inline_state()
  -- Clean up temporary file if it exists
  if inline_state.temp_file then
    os.remove(inline_state.temp_file)
  end

  inline_state = {
    original_buf = nil,
    original_text = nil,
    new_text = nil,
    start_line = nil,
    end_line = nil,
    prompt_type = nil,
    temp_file = nil,
    has_gitsigns = false,
  }
end

-- Apply inline diff using buffer modifications and extmarks
local function apply_inline_diff(buf, original_text, new_text, start_line, _)
  local ns = api.nvim_create_namespace('correctme_inline_preview')

  -- Clear any existing inline preview
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local original_lines = vim.split(original_text, '\n')
  local new_lines = vim.split(new_text, '\n')

  -- Add header showing the rewrite type and instructions
  local header_text = {
    { '━━━ ', 'Comment' },
    { '🔄 ' .. string.upper(inline_state.prompt_type) .. ' PREVIEW', 'Title' },
    {
      ' ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      'Comment',
    },
  }

  api.nvim_buf_set_extmark(buf, ns, start_line, 0, {
    virt_lines = { header_text },
    virt_lines_above = true,
  })

  -- Process line by line to show inline diff
  for i = 1, math.max(#original_lines, #new_lines) do
    local orig_line = original_lines[i] or ''
    local new_line = new_lines[i] or ''
    local line_idx = start_line + i - 1

    if orig_line ~= new_line then
      -- Handle removed lines (original content that's being changed/deleted)
      if orig_line ~= '' and new_line ~= '' then
        -- Modified line - highlight original as changed
        api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
          end_col = #orig_line > 0 and #orig_line or 1,
          hl_group = 'DiffDelete',
          hl_eol = true,
          sign_text = '~',
          sign_hl_group = 'DiffChange',
        })

        -- Add the new line as virtual text below
        local virt_text = {
          { '+ ', 'CorrectmeInlineAdd' },
          { new_line, 'CorrectmeInlineAdd' },
        }

        api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
          virt_lines = { virt_text },
          virt_lines_above = false,
        })
      elseif orig_line ~= '' and new_line == '' then
        -- Deleted line
        api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
          end_col = #orig_line > 0 and #orig_line or 1,
          hl_group = 'DiffDelete',
          hl_eol = true,
          sign_text = '-',
          sign_hl_group = 'CorrectmeInlineDelete',
        })
      elseif orig_line == '' and new_line ~= '' then
        -- Added line - show as virtual text
        local virt_text = {
          { '+ ', 'CorrectmeInlineAdd' },
          { new_line, 'CorrectmeInlineAdd' },
        }

        -- Add virtual line at the appropriate position
        local insert_line = line_idx > 0 and line_idx - 1 or 0
        api.nvim_buf_set_extmark(buf, ns, insert_line, 0, {
          virt_lines = { virt_text },
          virt_lines_above = false,
        })
      end
    end
  end

  -- Add footer with instructions
  local footer_text = {
    { '━━━ ', 'Comment' },
    { 'Press ', 'Comment' },
    { '<leader>aa', 'Keyword' },
    { ' to accept, ', 'Comment' },
    { '<leader>ar', 'Keyword' },
    { ' to reject ', 'Comment' },
    {
      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
      'Comment',
    },
  }

  local last_line = start_line + math.max(#original_lines, 1) - 1
  api.nvim_buf_set_extmark(buf, ns, last_line, 0, {
    virt_lines = { footer_text },
    virt_lines_above = false,
  })

  return ns
end

-- Accept the inline changes
M.accept_changes = function()
  if not inline_state.original_buf or not inline_state.new_text then
    print('No inline preview to accept')
    return
  end

  -- Check if buffer is valid and modifiable
  if not api.nvim_buf_is_valid(inline_state.original_buf) then
    print('Original buffer is no longer valid')
    clear_inline_state()
    return
  end

  -- Temporarily make buffer modifiable if needed
  local was_modifiable = api.nvim_buf_get_option(inline_state.original_buf, 'modifiable')
  if not was_modifiable then
    api.nvim_buf_set_option(inline_state.original_buf, 'modifiable', true)
  end

  -- Apply changes to original buffer
  local success, err = pcall(function()
    local new_lines = vim.split(inline_state.new_text, '\n')
    api.nvim_buf_set_lines(
      inline_state.original_buf,
      inline_state.start_line,
      inline_state.end_line,
      false,
      new_lines
    )
  end)

  -- Restore original modifiable state
  if not was_modifiable then
    api.nvim_buf_set_option(inline_state.original_buf, 'modifiable', false)
  end

  if success then
    print('Inline changes accepted!')
  else
    print('Failed to apply changes: ' .. (err or 'unknown error'))
  end

  -- Clear inline preview
  M.clear_inline_preview()
  clear_inline_state()
end

-- Reject the inline changes
M.reject_changes = function()
  print('Inline changes rejected')
  M.clear_inline_preview()
  clear_inline_state()
end

-- Clear inline preview extmarks
M.clear_inline_preview = function()
  if inline_state.original_buf and api.nvim_buf_is_valid(inline_state.original_buf) then
    local ns = api.nvim_create_namespace('correctme_inline_preview')
    api.nvim_buf_clear_namespace(inline_state.original_buf, ns, 0, -1)
  end
end

-- Show inline preview using gitsigns-style approach
M.show_inline_preview = function(
  original_buf,
  original_text,
  new_text,
  start_line,
  end_line,
  prompt_type
)
  -- Store state
  inline_state.original_buf = original_buf
  inline_state.original_text = original_text
  inline_state.new_text = new_text
  inline_state.start_line = start_line
  inline_state.end_line = end_line
  inline_state.prompt_type = prompt_type

  -- Clear any existing inline preview
  M.clear_inline_preview()

  -- Setup highlight groups
  setup_inline_highlights()

  -- Use our enhanced inline diff implementation (gitsigns only works with actual git changes)
  apply_inline_diff(original_buf, original_text, new_text, start_line, end_line)

  -- Set up buffer-local keymaps for accept/reject
  local opts = { buffer = original_buf, noremap = true, silent = true }
  vim.keymap.set('n', '<leader>aa', M.accept_changes, opts)
  vim.keymap.set('n', '<leader>ar', M.reject_changes, opts)

  print('Inline preview ready! Press <leader>aa to accept, <leader>ar to reject')
end

-- Check if inline preview is active
M.is_preview_active = function()
  return inline_state.original_buf ~= nil and api.nvim_buf_is_valid(inline_state.original_buf)
end

return M
