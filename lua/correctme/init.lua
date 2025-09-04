-- lua/correctme/init.lua
-- Main module that composes all functionality

local M = {}

-- Lazy load modules
local config, providers, utils, cache, diff, statusline, diagnostics, preview
local api = vim.api
local fn = vim.fn

-- Plugin state
local state = {
  config = nil,
  timer = nil,
  initialized = false,
}

-- Load modules on demand
local function load_modules()
  if not state.initialized then
    config = require('correctme.config')
    providers = require('correctme.providers')
    utils = require('correctme.utils')
    cache = require('correctme.cache')
    diff = require('correctme.diff')
    statusline = require('correctme.statusline')
    diagnostics = require('correctme.diagnostics')
    preview = require('correctme.preview')
    state.initialized = true
  end
end

-- Helper function to call AI provider with current configuration
local function call_ai_provider(prompt, callback)
  providers.call_ai_provider(
    prompt,
    callback,
    state.config.provider,
    state.config.providers,
    state.config.defaults
  )
end

-- One-time check of entire document
M.check_document = function()
  load_modules()
  local bufnr = api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, '\n')
  local paragraphs = utils.split_paragraphs(text)

  if #paragraphs == 0 then
    print('No text to check')
    return
  end

  print('Checking ' .. #paragraphs .. ' paragraphs...')

  local errors = {}
  local pending = #paragraphs

  -- Clear any existing diagnostics first
  diagnostics.clear_diagnostics(bufnr)

  for i, paragraph in ipairs(paragraphs) do
    cache.check_paragraph(paragraph, i, function(error, _)
      if error then
        table.insert(errors, error)
      end
      pending = pending - 1
      if pending == 0 then
        diagnostics.apply_diagnostics(bufnr, errors)
        if #errors > 0 then
          print('Found ' .. #errors .. ' suggestions. Use <leader>aa to accept corrections.')
        else
          print('No grammar issues found!')
        end
      end
    end, call_ai_provider, state.config.prompts)
  end
end

-- Interactive document check with diff mode
M.check_document_diff = function()
  load_modules()
  diff.check_document_diff(call_ai_provider, state.config.prompts)
end

-- Start checking current buffer
M.start_checking = function()
  load_modules()
  if state.timer then
    print('Already checking')
    return
  end

  local bufnr = api.nvim_get_current_buf()
  print('Starting continuous checking...')

  state.timer = vim.uv.new_timer()
  if not state.timer then
    print('Failed to create timer')
    return
  end

  state.timer:start(1000, state.config.check_interval, function()
    vim.schedule(function()
      cache.check_buffer_smart(
        bufnr,
        call_ai_provider,
        state.config.prompts,
        diagnostics.apply_diagnostics
      )
    end)
  end)
end

-- Stop checking
M.stop_checking = function()
  load_modules()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
    print('Stopped checking')
  end
  -- Clear buffer state and cache
  cache.clear_cache()
  diagnostics.clear_diagnostics()
end

-- Rewrite selected text or whole document with specified prompt type
M.rewrite_selection = function(prompt_type, range_info)
  load_modules()
  prompt_type = prompt_type or 'rewrite'

  -- Validate prompt type
  if not state.config.prompts[prompt_type] then
    print('Invalid prompt type: ' .. prompt_type)
    print('Available types: ' .. table.concat(vim.tbl_keys(state.config.prompts), ', '))
    return
  end

  local start_line, end_line, text

  -- Check if we have range information (called from command with range)
  if range_info and range_info.line1 and range_info.line2 then
    -- Range provided from command
    start_line = range_info.line1 - 1
    end_line = range_info.line2
    local lines = api.nvim_buf_get_lines(0, start_line, end_line, false)
    text = table.concat(lines, '\n')
  else
    -- Check for visual selection
    local start_pos = fn.getpos("'<")
    local end_pos = fn.getpos("'>")

    -- Check if we have a valid visual selection
    if start_pos[2] > 0 and end_pos[2] > 0 and start_pos[2] <= end_pos[2] then
      start_line = start_pos[2] - 1
      end_line = end_pos[2]
      local lines = api.nvim_buf_get_lines(0, start_line, end_line, false)
      text = table.concat(lines, '\n')
    else
      -- No selection, use whole document
      start_line = 0
      local lines = api.nvim_buf_get_lines(0, 0, -1, false)
      text = table.concat(lines, '\n')
      end_line = #lines
    end
  end

  if text == '' then
    print('No text to rewrite')
    return
  end

  print('Rewriting text with ' .. prompt_type .. ' style...')

  local prompt = state.config.prompts[prompt_type]:gsub('{text}', text)

  call_ai_provider(prompt, function(response)
    if response then
      -- Clean response (remove extra whitespace)
      response = vim.trim(response)
      -- Show preview instead of directly applying changes
      local current_buf = api.nvim_get_current_buf()
      preview.show_preview(current_buf, text, response, start_line, end_line, prompt_type)
    else
      print('Failed to rewrite text')
    end
  end)
end

-- Accept diagnostic suggestion at cursor
M.accept_suggestion = function()
  load_modules()
  diagnostics.accept_suggestion()
end

-- Get synonyms for selection
M.get_synonyms = function()
  load_modules()
  local word = fn.expand('<cword>')
  local prompt = state.config.prompts.synonyms:gsub('{expression}', word)

  call_ai_provider(prompt, function(response)
    if response then
      local synonyms = vim.split(response, '\n')
      -- Show in floating window
      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, 0, -1, false, synonyms)

      local width = 30
      local height = #synonyms

      api.nvim_open_win(buf, true, {
        relative = 'cursor',
        row = 1,
        col = 0,
        width = width,
        height = height,
        border = 'single',
        title = " Synonyms for '" .. word .. "' ",
        title_pos = 'center',
      })
    end
  end)
end

-- Accept preview changes
M.accept_preview = function()
  load_modules()
  preview.accept_changes()
end

-- Reject preview changes
M.reject_preview = function()
  load_modules()
  preview.reject_changes()
end

-- Expose statusline function
M.statusline = function()
  load_modules()
  return statusline.statusline()
end

-- Setup function
M.setup = function(opts)
  load_modules()
  state.config = config.get_config(opts)

  -- Create commands
  vim.cmd([[
    command! LLMStartChecking lua require('correctme').start_checking()
    command! LLMStopChecking lua require('correctme').stop_checking()
    command! LLMCheckDocument lua require('correctme').check_document()
    command! LLMCheckDocumentDiff lua require('correctme').check_document_diff()
    command! -range=% LLMRewrite lua require('correctme').rewrite_selection(
      \ 'rewrite', {line1=<line1>, line2=<line2>})
    command! -range=% LLMProofread lua require('correctme').rewrite_selection(
      \ 'proofread', {line1=<line1>, line2=<line2>})
    command! -range=% LLMRephrase lua require('correctme').rewrite_selection(
      \ 'rephrase', {line1=<line1>, line2=<line2>})
    command! -range=% LLMProfessional lua require('correctme').rewrite_selection(
      \ 'professional', {line1=<line1>, line2=<line2>})
    command! -range=% LLMFriendly lua require('correctme').rewrite_selection(
      \ 'friendly', {line1=<line1>, line2=<line2>})
    command! -range=% LLMEmojify lua require('correctme').rewrite_selection(
      \ 'emojify', {line1=<line1>, line2=<line2>})
    command! -range=% LLMElaborate lua require('correctme').rewrite_selection(
      \ 'elaborate', {line1=<line1>, line2=<line2>})
    command! -range=% LLMShorten lua require('correctme').rewrite_selection(
      \ 'shorten', {line1=<line1>, line2=<line2>})
    command! LLMSynonyms lua require('correctme').get_synonyms()
    command! LLMAccept lua require('correctme').accept_suggestion()
    command! LLMAcceptPreview lua require('correctme').accept_preview()
    command! LLMRejectPreview lua require('correctme').reject_preview()
  ]])

  -- Set up code actions for quick fixes
  api.nvim_create_autocmd('CursorHold', {
    callback = function()
      local diagnostics_list = vim.diagnostic.get(0, {
        namespace = diagnostics.get_namespace(),
        lnum = fn.line('.') - 1,
      })

      if #diagnostics_list > 0 then
        -- Register code action
        vim.lsp.buf.code_action = function()
          for _, diag in ipairs(diagnostics_list) do
            if diag.user_data and diag.user_data.correction then
              -- Apply the correction
              local line = fn.line('.')
              api.nvim_buf_set_lines(0, line - 1, line, false, { diag.user_data.correction })
            end
          end
        end
      end
    end,
  })
end

return M
