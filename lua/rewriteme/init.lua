-- lua/rewriteme/init.lua
local M = {}
local api = vim.api
local fn = vim.fn

M.config = {
	-- Current provider name
	provider = "local-ollama",

	-- Provider configurations with type field and env var mappings
	providers = {
		["local-ollama"] = {
			type = "ollama",
			model = "llama3.2:3b",
			api_key = nil,
			base_url = "http://localhost:11434",
			max_tokens = 1000,
			env = {
				base_url = "OLLAMA_BASE_URL",
				api_key = "OLLAMA_API_KEY",
			},
		},
		["gpt-3.5"] = {
			type = "openai",
			model = "gpt-3.5-turbo",
			api_key = nil,
			base_url = nil,
			max_tokens = 1000,
			env = {
				base_url = "OPENAI_BASE_URL",
				api_key = "OPENAI_API_KEY",
			},
		},
		["gpt-4"] = {
			type = "openai",
			model = "gpt-4",
			api_key = nil,
			base_url = nil,
			max_tokens = 2000,
			env = {
				base_url = "OPENAI_BASE_URL",
				api_key = "OPENAI_API_KEY",
			},
		},
		["claude-haiku"] = {
			type = "anthropic",
			model = "claude-3-haiku-20240307",
			api_key = nil,
			base_url = nil,
			max_tokens = 1000,
			env = {
				base_url = "ANTHROPIC_BASE_URL",
				api_key = "ANTHROPIC_API_KEY",
			},
		},
		["claude-sonnet"] = {
			type = "anthropic",
			model = "claude-3-sonnet-20240229",
			api_key = nil,
			base_url = nil,
			max_tokens = 2000,
			env = {
				base_url = "ANTHROPIC_BASE_URL",
				api_key = "ANTHROPIC_API_KEY",
			},
		},
	},

	-- Default values for provider types when config values are nil
	defaults = {
		openai = {
			base_url = "https://api.openai.com/v1",
		},
		anthropic = {
			base_url = "https://api.anthropic.com/v1",
		},
		ollama = {
			base_url = "http://localhost:11434",
		},
	},

	-- Prompts
	prompts = {
		proofreading = [[Proofread the following message in American English. If it is grammatically correct, just respond with the word "Correct". If it is grammatically incorrect or has spelling mistakes, respond with "Correction: ", followed by the corrected version.
{text}]],
		rewrite = [[Rewrite the following text for clarity in its original language. Keep the same meaning but improve readability. Respond with ONLY the improved text:
{text}]],
		synonyms = [[Give up to 5 synonyms for the expression "{expression}". Just respond with the synonyms, separated by newlines.]],
	},

	-- Check interval in milliseconds
	check_interval = 5000,
}

-- Namespace for diagnostics
local ns = api.nvim_create_namespace("rewriteme")

-- Cache for processed texts and buffer state
local cache = {}
local buffer_state = {
	last_content_hash = nil,
	processed_paragraphs = {},
}

-- Timer for continuous checking
local timer = nil

-- Query execution state
local query_state = {
	active_queries = 0,
	icon = "🤖",
	spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
	spinner_index = 1,
}

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

-- Function to resolve provider configuration with environment variable fallback
local function resolve_provider_config(provider_config)
	local resolved = vim.deepcopy(provider_config)
	local defaults = M.config.defaults[provider_config.type] or {}

	-- Resolve each field with env var fallback, then defaults
	for field, env_var in pairs(provider_config.env or {}) do
		if resolved[field] == nil then
			-- Try environment variable first
			resolved[field] = os.getenv(env_var)
			-- Fall back to defaults if still nil
			if resolved[field] == nil and defaults[field] then
				resolved[field] = defaults[field]
			end
		end
	end

	return resolved
end

-- Generate a simple hash for content
local function hash_content(text)
	local hash = 0
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 2147483647
	end
	return hash
end

-- Functions to manage query state
local function start_query()
	query_state.active_queries = query_state.active_queries + 1
	if query_state.active_queries == 1 then
		-- Start spinner timer
		vim.fn.timer_start(100, function()
			if query_state.active_queries > 0 then
				query_state.spinner_index = (query_state.spinner_index % #query_state.spinner_frames) + 1
				vim.cmd("redrawstatus")
			end
		end, { ["repeat"] = -1 })
	end
end

local function end_query()
	query_state.active_queries = math.max(0, query_state.active_queries - 1)
	if query_state.active_queries == 0 then
		vim.cmd("redrawstatus")
	end
end

-- Statusline function
M.statusline = function()
	if query_state.active_queries > 0 then
		local spinner = query_state.spinner_frames[query_state.spinner_index]
		return string.format("%s AI (%d)", spinner, query_state.active_queries)
	end
	return ""
end

-- Function to call OpenAI API
local function call_openai(prompt, callback, config)
	if not config.api_key then
		print(
			"OpenAI API key not found. Set "
				.. (config.env and config.env.api_key or "OPENAI_API_KEY")
				.. " environment variable."
		)
		return
	end

	local curl_cmd = string.format(
		"curl -s -X POST %s/chat/completions -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' -d %s",
		config.base_url,
		config.api_key,
		fn.shellescape(fn.json_encode({
			model = config.model,
			messages = { { role = "user", content = prompt } },
			max_tokens = config.max_tokens,
		}))
	)

	vim.fn.jobstart(curl_cmd, {
		on_stdout = function(_, data, _)
			local response = table.concat(data, "\n")
			local ok, result = pcall(fn.json_decode, response)
			if ok and result.choices and result.choices[1] and result.choices[1].message then
				callback(result.choices[1].message.content)
			end
		end,
	})
end

-- Function to call Anthropic API
local function call_anthropic(prompt, callback, config)
	if not config.api_key then
		print(
			"Anthropic API key not found. Set "
				.. (config.env and config.env.api_key or "ANTHROPIC_API_KEY")
				.. " environment variable."
		)
		return
	end

	local curl_cmd = string.format(
		"curl -s -X POST %s/messages -H 'x-api-key: %s' -H 'Content-Type: application/json' -H 'anthropic-version: 2023-06-01' -d %s",
		config.base_url,
		config.api_key,
		fn.shellescape(fn.json_encode({
			model = config.model,
			max_tokens = config.max_tokens,
			messages = { { role = "user", content = prompt } },
		}))
	)

	vim.fn.jobstart(curl_cmd, {
		on_stdout = function(_, data, _)
			local response = table.concat(data, "\n")
			local ok, result = pcall(fn.json_decode, response)
			if ok and result.content and result.content[1] and result.content[1].text then
				callback(result.content[1].text)
			end
		end,
	})
end

-- Function to call Ollama API
local function call_ollama(prompt, callback, config)
	local curl_cmd = string.format(
		"curl -s -X POST %s/api/generate -d %s",
		config.base_url,
		fn.shellescape(fn.json_encode({
			model = config.model,
			prompt = prompt,
			stream = false,
		}))
	)

	vim.fn.jobstart(curl_cmd, {
		on_stdout = function(_, data, _)
			local response = table.concat(data, "\n")
			local ok, result = pcall(fn.json_decode, response)
			if ok and result.response then
				callback(result.response)
			end
		end,
	})
end

-- Unified function to call the configured AI provider
local function call_ai_provider(prompt, callback)
	local provider_config = M.config.providers[M.config.provider]
	if not provider_config then
		print("Provider '" .. M.config.provider .. "' not found in configuration")
		return
	end

	-- Resolve configuration with environment variables and defaults
	local resolved_config = resolve_provider_config(provider_config)

	-- Start query tracking
	start_query()

	-- Wrap callback to track query completion
	local wrapped_callback = function(response)
		end_query()
		callback(response)
	end

	if resolved_config.type == "openai" then
		call_openai(prompt, wrapped_callback, resolved_config)
	elseif resolved_config.type == "anthropic" then
		call_anthropic(prompt, wrapped_callback, resolved_config)
	elseif resolved_config.type == "ollama" then
		call_ollama(prompt, wrapped_callback, resolved_config)
	else
		end_query() -- End query on error
		print("Unknown provider type: " .. tostring(resolved_config.type))
	end
end

-- Split text into paragraphs
local function split_paragraphs(text)
	local paragraphs = {}
	local current = ""

	for line in text:gmatch("[^\n]*") do
		if line == "" then
			if current ~= "" then
				table.insert(paragraphs, current)
				current = ""
			end
		else
			current = current .. (current == "" and "" or "\n") .. line
		end
	end

	if current ~= "" then
		table.insert(paragraphs, current)
	end

	return paragraphs
end

-- Check a single paragraph
local function check_paragraph(text, line_num, callback)
	local cache_key = text
	if cache[cache_key] then
		callback(cache[cache_key], line_num)
		return
	end

	-- Extract indentation and clean text for AI
	local indent = text:match("^%s*") or ""
	local clean_text = text:gsub("^%s*", "") -- Remove leading whitespace for AI
	
	local prompt = M.config.prompts.proofreading:gsub("{text}", clean_text)

	call_ai_provider(prompt, function(response)
		-- Debug logging (remove when working)
		-- print("AI Response for paragraph " .. line_num .. ":")
		-- print("Text: '" .. clean_text .. "'")
		-- print("Response: '" .. tostring(response) .. "'")
		
		local result = nil
		if response and not response:match("^Correct$") and not response:match("^Correct%.") then
			-- Look for "Correction:" in the response
			if response:match("Correction:") then
				-- Try to extract correction from response
				local correction = response:match("Correction:%s*(.+)")
				if correction then
					-- Clean up the correction (remove extra explanations)
					correction = correction:match("^(.-)\n\nNote:") or correction
					correction = correction:match("^(.-)\n\n%(") or correction  
					correction = correction:gsub("\n+", " "):gsub("%s+", " ")
					correction = vim.trim(correction)
					
					if correction:len() > 0 then
						-- Clean up the correction more aggressively
						correction = correction:match("^(.-)\n\nExplanation") or correction
						correction = correction:match("^(.-)%. Explanation") or correction
						correction = correction:match("^(.-) Explanation") or correction
						correction = vim.trim(correction)
						
						result = {
							original = text,
							correction = indent .. correction, -- Preserve original indentation
							line = line_num,
						}
						-- print("Found error - correction: " .. correction)
					else
						-- print("Empty correction extracted")
					end
				else
					-- print("Could not extract correction from: " .. tostring(response))
				end
			else
				-- print("No 'Correction:' found in response: " .. tostring(response))
			end
		else
			-- print("Text is correct or no response")
		end
		cache[cache_key] = result
		callback(result, line_num)
	end)
end

-- Apply diagnostics for errors
local function apply_diagnostics(bufnr, errors)
	local diagnostics = {}

	for _, error in ipairs(errors) do
		table.insert(diagnostics, {
			lnum = error.line - 1,
			col = 0,
			end_lnum = error.line - 1,
			end_col = #error.original,
			message = "Suggestion: " .. error.correction,
			severity = vim.diagnostic.HINT,
			source = "rewriteme",
			user_data = error,
		})
	end

	vim.diagnostic.set(ns, bufnr, diagnostics)
end

-- Start checking current buffer
M.start_checking = function()
	if timer then
		M.stop_checking()
	end

	local bufnr = api.nvim_get_current_buf()

	local function check_buffer()
		local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local text = table.concat(lines, "\n")
		local content_hash = hash_content(text)

		-- Skip if content hasn't changed
		if buffer_state.last_content_hash == content_hash then
			return
		end

		buffer_state.last_content_hash = content_hash
		local paragraphs = split_paragraphs(text)

		-- Create paragraph hashes to detect changes
		local current_paragraph_hashes = {}
		for i, paragraph in ipairs(paragraphs) do
			current_paragraph_hashes[i] = hash_content(paragraph)
		end

		local errors = {}
		local pending = 0

		-- Only check paragraphs that have changed
		for i, paragraph in ipairs(paragraphs) do
			local para_hash = current_paragraph_hashes[i]
			if not buffer_state.processed_paragraphs[para_hash] then
				pending = pending + 1
				check_paragraph(paragraph, i, function(error, _)
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
						apply_diagnostics(bufnr, all_errors)
					end
				end)
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
			apply_diagnostics(bufnr, errors)
		end
	end

	-- Initial check
	check_buffer()

	-- Set up timer for continuous checking
	timer = fn.timer_start(M.config.check_interval, check_buffer, { ["repeat"] = -1 })
end

-- Stop checking
M.stop_checking = function()
	if timer then
		fn.timer_stop(timer)
		timer = nil
	end
	-- Clear buffer state and cache
	buffer_state.last_content_hash = nil
	buffer_state.processed_paragraphs = {}
	cache = {}
	vim.diagnostic.reset(ns)
end

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
	api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	
	-- Highlight current line
	local line_num = suggestion.line - 1
	api.nvim_buf_add_highlight(bufnr, ns, "DiffDelete", line_num, 0, -1)
	
	-- Show virtual text with suggested correction (indentation already preserved)
	api.nvim_buf_set_virtual_text(bufnr, ns, line_num, {
		{string.format("  → %s", suggestion.correction), "DiffAdd"},
		{string.format("  [%d/%d] (y)es/(n)o/(q)uit", diff_state.current_index, #diff_state.suggestions), "Comment"}
	}, {})
	
	-- Move cursor to the line
	api.nvim_win_set_cursor(0, {suggestion.line, 0})
	
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
	local current_line = api.nvim_buf_get_lines(diff_state.buffer, line_num, line_num + 1, false)[1] or ""
	print(string.format("Replacing line %d: '%s' → '%s'", suggestion.line, current_line, suggestion.correction))
	
	-- Replace the line with the correction (indentation already preserved)
	api.nvim_buf_set_lines(diff_state.buffer, line_num, line_num + 1, false, {suggestion.correction})
	
	next_suggestion()
end

-- Exit diff mode
exit_diff_mode = function()
	if not diff_state.active then
		return
	end
	
	-- Clear highlights
	if diff_state.buffer and diff_state.namespace then
		api.nvim_buf_clear_namespace(diff_state.buffer, diff_state.namespace, 0, -1)
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
		api.nvim_buf_clear_namespace(diff_state.buffer, diff_state.namespace, 0, -1)
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
M.check_document_diff = function()
	local bufnr = api.nvim_get_current_buf()
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	
	-- Build paragraph to line mapping
	local paragraph_to_line = {}
	local paragraphs = {}
	local current_paragraph = ""
	local current_line_num = 1
	local paragraph_start_line = 1
	
	for line_num, line in ipairs(lines) do
		if line == "" then
			if current_paragraph ~= "" then
				table.insert(paragraphs, current_paragraph)
				paragraph_to_line[#paragraphs] = paragraph_start_line
				current_paragraph = ""
			end
			paragraph_start_line = line_num + 1
		else
			current_paragraph = current_paragraph .. (current_paragraph == "" and "" or "\n") .. line
		end
	end
	
	-- Add last paragraph if exists
	if current_paragraph ~= "" then
		table.insert(paragraphs, current_paragraph)
		paragraph_to_line[#paragraphs] = paragraph_start_line
	end
	
	if #paragraphs == 0 then
		print("No text to check")
		return
	end
	
	print("Checking " .. #paragraphs .. " paragraphs for interactive diff...")
	
	local errors = {}
	local pending = #paragraphs
	
	for i, paragraph in ipairs(paragraphs) do
		local actual_line = paragraph_to_line[i]
		check_paragraph(paragraph, actual_line, function(error, _)
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
					diff_state.namespace = api.nvim_create_namespace("rewriteme_diff")
					
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
		end)
	end
end

-- One-time check of entire document
M.check_document = function()
	local bufnr = api.nvim_get_current_buf()
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local text = table.concat(lines, "\n")
	local paragraphs = split_paragraphs(text)
	
	if #paragraphs == 0 then
		print("No text to check")
		return
	end
	
	print("Checking " .. #paragraphs .. " paragraphs...")
	
	local errors = {}
	local pending = #paragraphs
	
	-- Clear any existing diagnostics first
	vim.diagnostic.reset(ns, bufnr)
	
	for i, paragraph in ipairs(paragraphs) do
		check_paragraph(paragraph, i, function(error, _)
			if error then
				table.insert(errors, error)
			end
			pending = pending - 1
			if pending == 0 then
				apply_diagnostics(bufnr, errors)
				if #errors > 0 then
					print("Found " .. #errors .. " suggestions. Use <leader>aa to accept corrections.")
				else
					print("No grammar issues found!")
				end
			end
		end)
	end
end

-- Rewrite selected text
M.rewrite_selection = function()
	local start_pos = fn.getpos("'<")
	local end_pos = fn.getpos("'>")

	-- Ensure valid line range
	local start_line = start_pos[2] - 1
	local end_line = end_pos[2]

	if start_line < 0 or end_line < 0 or start_line > end_line then
		print("Invalid selection range")
		return
	end

	local lines = api.nvim_buf_get_lines(0, start_line, end_line, false)
	local text = table.concat(lines, "\n")

	if text == "" then
		print("No text selected")
		return
	end

	local prompt = M.config.prompts.rewrite:gsub("{text}", text)

	call_ai_provider(prompt, function(response)
		if response then
			-- Clean response (remove extra whitespace)
			response = vim.trim(response)
			-- Replace selection with rewritten text
			local new_lines = vim.split(response, "\n")
			api.nvim_buf_set_lines(0, start_line, end_line, false, new_lines)
		end
	end)
end

-- Accept diagnostic suggestion at cursor
M.accept_suggestion = function()
	local line = fn.line(".") - 1
	local diagnostics = vim.diagnostic.get(0, {
		namespace = ns,
		lnum = line,
	})
	
	if #diagnostics > 0 then
		local diag = diagnostics[1]
		if diag.user_data and diag.user_data.correction then
			-- Replace the line with the correction
			api.nvim_buf_set_lines(0, line, line + 1, false, {diag.user_data.correction})
			print("Applied correction: " .. diag.user_data.correction)
		else
			print("No correction data found")
		end
	else
		print("No diagnostics on current line")
	end
end

-- Get synonyms for selection
M.get_synonyms = function()
	local word = fn.expand("<cword>")
	local prompt = M.config.prompts.synonyms:gsub("{expression}", word)

	call_ai_provider(prompt, function(response)
		if response then
			local synonyms = vim.split(response, "\n")
			-- Show in floating window
			local buf = api.nvim_create_buf(false, true)
			api.nvim_buf_set_lines(buf, 0, -1, false, synonyms)

			local width = 30
			local height = #synonyms

			api.nvim_open_win(buf, true, {
				relative = "cursor",
				row = 1,
				col = 0,
				width = width,
				height = height,
				border = "single",
				title = " Synonyms for '" .. word .. "' ",
				title_pos = "center",
			})
		end
	end)
end

-- Setup function
M.setup = function(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create commands
	vim.cmd([[
    command! LLMStartChecking lua require('rewriteme').start_checking()
    command! LLMStopChecking lua require('rewriteme').stop_checking()
    command! LLMCheckDocument lua require('rewriteme').check_document()
    command! LLMCheckDocumentDiff lua require('rewriteme').check_document_diff()
    command! -range LLMRewrite lua require('rewriteme').rewrite_selection()
    command! LLMSynonyms lua require('rewriteme').get_synonyms()
    command! LLMAccept lua require('rewriteme').accept_suggestion()
  ]])

	-- Set up code actions for quick fixes
	api.nvim_create_autocmd("CursorHold", {
		callback = function()
			local diagnostics = vim.diagnostic.get(0, {
				namespace = ns,
				lnum = fn.line(".") - 1,
			})

			if #diagnostics > 0 then
				-- Register code action
				vim.lsp.buf.code_action = function()
					for _, diag in ipairs(diagnostics) do
						if diag.user_data and diag.user_data.correction then
							-- Apply the correction
							local line = fn.line(".")
							api.nvim_buf_set_lines(0, line - 1, line, false, { diag.user_data.correction })
						end
					end
				end
			end
		end,
	})
end

return M
