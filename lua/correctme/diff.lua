-- lua/correctme/diff.lua
-- Interactive diff mode for correctme.nvim

local utils = require('correctme.utils')
local cache = require('correctme.cache')
local inline_preview = require('correctme.inline_preview')
local interactive_preview = require('correctme.interactive_preview')

local M = {}

-- Interactive diff mode state
local diff_state = {
  active = false,
  suggestions = {},
  current_index = 1,
  buffer = nil,
  namespace = nil,
  preview_mode = 'buffer', -- 'buffer' or 'inline'
  config = nil,
}

-- Forward declarations for diff mode functions
local next_suggestion, exit_diff_mode

-- Show current suggestion using preview system
local function show_current_diff()
  if not diff_state.active or #diff_state.suggestions == 0 then
    return
  end

  local suggestion = diff_state.suggestions[diff_state.current_index]
  if not suggestion then
    return
  end

  local bufnr = diff_state.buffer
  local line_num = suggestion.line - 1

  -- Clear any existing previews
  if diff_state.preview_mode == 'inline' then
    inline_preview.clear_inline_preview()
  else
    interactive_preview.close_preview()
  end

  -- Move cursor to the line
  vim.api.nvim_win_set_cursor(0, { suggestion.line, 0 })

  -- Show preview based on mode
  if diff_state.preview_mode == 'inline' then
    -- Use inline preview for interactive mode
    inline_preview.show_inline_preview(
      bufnr,
      suggestion.original,
      suggestion.correction,
      line_num,
      line_num + 1,
      'interactive'
    )
  else
    -- Use interactive split preview (original on top, correction below)
    local suggestion_info =
      string.format('%d/%d', diff_state.current_index, #diff_state.suggestions)
    interactive_preview.show_interactive_preview(
      suggestion.original,
      suggestion.correction,
      'grammar',
      suggestion_info
    )
  end

  print(
    string.format(
      'Interactive mode %d/%d: %s → %s (y/n/q)',
      diff_state.current_index,
      #diff_state.suggestions,
      suggestion.original,
      suggestion.correction
    )
  )
end

-- Accept current suggestion
local function accept_current_suggestion()
  if not diff_state.active or #diff_state.suggestions == 0 then
    return
  end

  local suggestion = diff_state.suggestions[diff_state.current_index]
  if not suggestion then
    return
  end

  -- Apply the change - for interactive mode, we always apply manually since it's just suggestions
  local line_num = suggestion.line - 1
  vim.api.nvim_buf_set_lines(
    diff_state.buffer,
    line_num,
    line_num + 1,
    false,
    { suggestion.correction }
  )

  -- Clear the appropriate preview
  if diff_state.preview_mode == 'inline' then
    inline_preview.clear_inline_preview()
  else
    interactive_preview.close_preview()
  end

  print(string.format("Accepted: '%s' → '%s'", suggestion.original, suggestion.correction))
  next_suggestion()
end

-- Exit diff mode
exit_diff_mode = function()
  if not diff_state.active then
    return
  end

  -- Clear previews based on mode
  if diff_state.preview_mode == 'inline' then
    inline_preview.clear_inline_preview()
  else
    interactive_preview.close_preview()
  end

  -- Clear highlights
  if diff_state.buffer and diff_state.namespace then
    vim.api.nvim_buf_clear_namespace(diff_state.buffer, diff_state.namespace, 0, -1)
  end

  -- Reset state
  diff_state.active = false
  diff_state.suggestions = {}
  diff_state.current_index = 1
  diff_state.buffer = nil
  diff_state.namespace = nil
  diff_state.config = nil

  print('Exited interactive diff mode')
end

-- Move to next suggestion
next_suggestion = function()
  if not diff_state.active or #diff_state.suggestions == 0 then
    return
  end

  -- Remove current suggestion
  table.remove(diff_state.suggestions, diff_state.current_index)

  -- Adjust index if we removed the last item
  if diff_state.current_index > #diff_state.suggestions then
    diff_state.current_index = #diff_state.suggestions
  end

  -- Clear previous previews
  if diff_state.preview_mode == 'inline' then
    inline_preview.clear_inline_preview()
  else
    interactive_preview.close_preview()
  end

  -- Clear previous highlights before moving to next
  if diff_state.buffer and diff_state.namespace then
    vim.api.nvim_buf_clear_namespace(diff_state.buffer, diff_state.namespace, 0, -1)
  end

  if #diff_state.suggestions == 0 then
    exit_diff_mode()
    print('All suggestions processed!')
  else
    show_current_diff()
  end
end

-- Decline current suggestion
local function decline_current_suggestion()
  print('Skipped suggestion')
  next_suggestion()
end

-- Interactive document check with diff mode
function M.check_document_diff(call_ai_provider, prompts, config)
  local api = vim.api
  local bufnr = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Build paragraph to line mapping
  local paragraphs, paragraph_to_line = utils.build_paragraph_mapping(lines)

  if #paragraphs == 0 then
    print('No text to check')
    return
  end

  print('Checking ' .. #paragraphs .. ' paragraphs for interactive diff...')

  local errors = {}
  local pending = #paragraphs

  for i, paragraph in ipairs(paragraphs) do
    local actual_line = paragraph_to_line[i]
    cache.check_paragraph(paragraph, actual_line, function(error, _)
      if error then
        -- Ensure line number is correct
        error.line = actual_line
        table.insert(errors, error)
      end
      pending = pending - 1
      if pending == 0 then
        if #errors > 0 then
          -- Sort errors by line number
          table.sort(errors, function(a, b)
            return a.line < b.line
          end)

          -- Enter diff mode
          diff_state.active = true
          diff_state.suggestions = errors
          diff_state.current_index = 1
          diff_state.buffer = bufnr
          diff_state.namespace = api.nvim_create_namespace('correctme_diff')
          diff_state.config = config or {}
          diff_state.preview_mode = (config and config.preview_mode) or 'buffer'

          print('Found ' .. #errors .. ' suggestions. Starting interactive diff mode...')
          show_current_diff()

          -- Set up keymaps for diff mode
          local opts = { buffer = bufnr, silent = true }
          vim.keymap.set('n', 'y', accept_current_suggestion, opts)
          vim.keymap.set('n', 'n', decline_current_suggestion, opts)
          vim.keymap.set('n', 'q', exit_diff_mode, opts)
          vim.keymap.set('n', '<Esc>', exit_diff_mode, opts)
        else
          print('No grammar issues found!')
        end
      end
    end, call_ai_provider, prompts)
  end
end

return M
