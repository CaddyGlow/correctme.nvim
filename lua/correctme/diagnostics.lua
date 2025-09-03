-- lua/correctme/diagnostics.lua
-- Diagnostic management for correctme.nvim

local M = {}

-- Namespace for diagnostics
local ns = vim.api.nvim_create_namespace('correctme')

-- Apply diagnostics to buffer
function M.apply_diagnostics(bufnr, errors)
  local diagnostics = {}

  for _, error in ipairs(errors) do
    table.insert(diagnostics, {
      lnum = error.line - 1,
      col = 0,
      end_lnum = error.line - 1,
      end_col = #error.original,
      message = 'Suggestion: ' .. error.correction,
      severity = vim.diagnostic.HINT,
      source = 'correctme',
      user_data = error,
    })
  end

  vim.diagnostic.set(ns, bufnr, diagnostics)
end

-- Accept diagnostic suggestion at cursor
function M.accept_suggestion()
  local fn = vim.fn
  local api = vim.api
  local line = fn.line('.') - 1
  local diagnostics = vim.diagnostic.get(0, {
    namespace = ns,
    lnum = line,
  })

  if #diagnostics > 0 then
    local diag = diagnostics[1]
    if diag.user_data and diag.user_data.correction then
      -- Replace the line with the correction
      api.nvim_buf_set_lines(0, line, line + 1, false, { diag.user_data.correction })
      print('Applied correction: ' .. diag.user_data.correction)
    else
      print('No correction data found')
    end
  else
    print('No diagnostics on current line')
  end
end

-- Clear diagnostics
function M.clear_diagnostics(bufnr)
  if bufnr then
    vim.diagnostic.reset(ns, bufnr)
  else
    vim.diagnostic.reset(ns)
  end
end

-- Get namespace
function M.get_namespace()
  return ns
end

return M
