-- lua/correctme/cache.lua
-- Smart caching system for correctme.nvim

local utils = require("correctme.utils")

local M = {}

-- Cache for processed texts
local cache = {}

-- Buffer state for smart caching
local buffer_state = {
	last_content_hash = nil,
	processed_paragraphs = {},
}

-- Check a single paragraph with caching
function M.check_paragraph(text, line_num, callback, call_ai_provider, prompts)
	local cache_key = text
	if cache[cache_key] then
		callback(cache[cache_key], line_num)
		return
	end

	-- Extract indentation and clean text for AI
	local indent = text:match("^%s*") or ""
	local clean_text = text:gsub("^%s*", "") -- Remove leading whitespace for AI
	
	local prompt = prompts.proofreading:gsub("{text}", clean_text)

	call_ai_provider(prompt, function(response)
		local correction = utils.clean_correction(response)
		local result = nil
		
		if correction then
			result = {
				original = text,
				correction = indent .. correction, -- Preserve original indentation
				line = line_num,
			}
		end
		
		cache[cache_key] = result
		callback(result, line_num)
	end)
end

-- Smart buffer checking with paragraph-level caching
function M.check_buffer_smart(bufnr, call_ai_provider, prompts, apply_diagnostics_callback)
	local api = vim.api
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local text = table.concat(lines, "\n")
	local content_hash = utils.hash_content(text)

	-- Skip if content hasn't changed
	if buffer_state.last_content_hash == content_hash then
		return
	end

	buffer_state.last_content_hash = content_hash
	local paragraphs = utils.split_paragraphs(text)

	-- Create paragraph hashes to detect changes
	local current_paragraph_hashes = {}
	for i, paragraph in ipairs(paragraphs) do
		current_paragraph_hashes[i] = utils.hash_content(paragraph)
	end

	local errors = {}
	local pending = 0

	-- Only check paragraphs that have changed
	for i, paragraph in ipairs(paragraphs) do
		local para_hash = current_paragraph_hashes[i]
		if not buffer_state.processed_paragraphs[para_hash] then
			pending = pending + 1
			M.check_paragraph(paragraph, i, function(error, _)
				-- Cache the result
				buffer_state.processed_paragraphs[para_hash] = error

				if error then
					table.insert(errors, error)
				end
				pending = pending - 1
				if pending == 0 then
					-- Collect all cached errors for current paragraphs
					local all_errors = {}
					for j, para in ipairs(paragraphs) do
						local cached_error = buffer_state.processed_paragraphs[current_paragraph_hashes[j]]
						if cached_error then
							-- Update line number for current position
							cached_error.line = j
							table.insert(all_errors, cached_error)
						end
					end
					apply_diagnostics_callback(bufnr, all_errors)
				end
			end, call_ai_provider, prompts)
		else
			-- Use cached result
			local cached_error = buffer_state.processed_paragraphs[para_hash]
			if cached_error then
				-- Update line number for current position
				cached_error.line = i
				table.insert(errors, cached_error)
			end
		end
	end

	-- If no new paragraphs to check, apply cached diagnostics immediately
	if pending == 0 then
		apply_diagnostics_callback(bufnr, errors)
	end
end

-- Clear all caches
function M.clear_cache()
	buffer_state.last_content_hash = nil
	buffer_state.processed_paragraphs = {}
	cache = {}
end

return M