-- lua/correctme/init.lua
-- Main module that composes all functionality

local M = {}

-- Lazy load modules
local config, providers, utils, cache, diff, statusline, diagnostics
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

-- Rewrite selected text
M.rewrite_selection = function()
  load_modules()
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")

  -- Ensure valid line range
  local start_line = start_pos[2] - 1
  local end_line = end_pos[2]

  if start_line < 0 or end_line < 0 or start_line > end_line then
    print('Invalid selection range')
    return
  end

  local lines = api.nvim_buf_get_lines(0, start_line, end_line, false)
  local text = table.concat(lines, '\n')

  if text == '' then
    print('No text selected')
    return
  end

  local prompt = state.config.prompts.rewrite:gsub('{text}', text)

  call_ai_provider(prompt, function(response)
    if response then
      -- Clean response (remove extra whitespace)
      response = vim.trim(response)
      -- Replace selection with rewritten text
      local new_lines = vim.split(response, '\n')
      api.nvim_buf_set_lines(0, start_line, end_line, false, new_lines)
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
    command! -range LLMRewrite lua require('correctme').rewrite_selection()
    command! LLMSynonyms lua require('correctme').get_synonyms()
    command! LLMAccept lua require('correctme').accept_suggestion()
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
