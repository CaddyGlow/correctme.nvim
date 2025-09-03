-- lua/correctme/diff.lua
-- Interactive diff mode for correctme.nvim

local utils = require("correctme.utils")
local cache = require("correctme.cache")

local M = {}

-- Interactive diff mode state
local diff_state = {
	active = false,
	suggestions = {},
	current_index = 1,
	buffer = nil,
	namespace = nil,
}

-- Forward declarations for diff mode functions
local next_suggestion, exit_diff_mode

-- Show inline diff for current suggestion
local function show_current_diff()
	if not diff_state.active or #diff_state.suggestions == 0 then
		return
	end
	
	local suggestion = diff_state.suggestions[diff_state.current_index]
	if not suggestion then
		return
	end
	
	local bufnr = diff_state.buffer
	local ns = diff_state.namespace
	
	-- Clear previous highlights
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	
	-- Highlight current line
	local line_num = suggestion.line - 1
	vim.api.nvim_buf_add_highlight(bufnr, ns, "DiffDelete", line_num, 0, -1)
	
	-- Show virtual text with suggested correction (indentation already preserved)
	vim.api.nvim_buf_set_virtual_text(bufnr, ns, line_num, {
		{string.format("  → %s", suggestion.correction), "DiffAdd"},
		{string.format("  [%d/%d] (y)es/(n)o/(q)uit", diff_state.current_index, #diff_state.suggestions), "Comment"}
	}, {})
	
	-- Move cursor to the line
	vim.api.nvim_win_set_cursor(0, {suggestion.line, 0})
	
	print(string.format("Suggestion %d/%d: %s → %s", 
		diff_state.current_index, 
		#diff_state.suggestions,
		suggestion.original,
		suggestion.correction))
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
	
	-- Debug: print what we're replacing
	local line_num = suggestion.line - 1
	local current_line = vim.api.nvim_buf_get_lines(diff_state.buffer, line_num, line_num + 1, false)[1] or ""
	print(string.format("Replacing line %d: '%s' → '%s'", suggestion.line, current_line, suggestion.correction))
	
	-- Replace the line with the correction (indentation already preserved)
	vim.api.nvim_buf_set_lines(diff_state.buffer, line_num, line_num + 1, false, {suggestion.correction})
	
	next_suggestion()
end

-- Exit diff mode
exit_diff_mode = function()
	if not diff_state.active then
		return
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
	
	print("Exited diff mode")
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
	
	-- Clear previous highlights before moving to next
	if diff_state.buffer and diff_state.namespace then
		vim.api.nvim_buf_clear_namespace(diff_state.buffer, diff_state.namespace, 0, -1)
	end
	
	if #diff_state.suggestions == 0 then
		exit_diff_mode()
		print("All suggestions processed!")
	else
		show_current_diff()
	end
end

-- Decline current suggestion
local function decline_current_suggestion()
	print("Skipped suggestion")
	next_suggestion()
end

-- Interactive document check with diff mode
function M.check_document_diff(call_ai_provider, prompts)
	local api = vim.api
	local bufnr = api.nvim_get_current_buf()
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	
	-- Build paragraph to line mapping
	local paragraphs, paragraph_to_line = utils.build_paragraph_mapping(lines)
	
	if #paragraphs == 0 then
		print("No text to check")
		return
	end
	
	print("Checking " .. #paragraphs .. " paragraphs for interactive diff...")
	
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
					table.sort(errors, function(a, b) return a.line < b.line end)
					
					-- Enter diff mode
					diff_state.active = true
					diff_state.suggestions = errors
					diff_state.current_index = 1
					diff_state.buffer = bufnr
					diff_state.namespace = api.nvim_create_namespace("correctme_diff")
					
					print("Found " .. #errors .. " suggestions. Starting interactive diff mode...")
					show_current_diff()
					
					-- Set up keymaps for diff mode
					local opts = { buffer = bufnr, silent = true }
					vim.keymap.set('n', 'y', accept_current_suggestion, opts)
					vim.keymap.set('n', 'n', decline_current_suggestion, opts)
					vim.keymap.set('n', 'q', exit_diff_mode, opts)
					vim.keymap.set('n', '<Esc>', exit_diff_mode, opts)
				else
					print("No grammar issues found!")
				end
			end
		end, call_ai_provider, prompts)
	end
end

return M