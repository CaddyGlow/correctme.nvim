-- lua/correctme/statusline.lua
-- Statusline integration and query tracking for correctme.nvim

local M = {}

-- Query execution state
local query_state = {
	active_queries = 0,
	icon = "🤖",
	spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
	spinner_index = 1,
}

-- Functions to manage query state
function M.start_query()
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

function M.end_query()
	query_state.active_queries = math.max(0, query_state.active_queries - 1)
	if query_state.active_queries == 0 then
		vim.cmd("redrawstatus")
	end
end

-- Statusline function
function M.statusline()
	if query_state.active_queries > 0 then
		local spinner = query_state.spinner_frames[query_state.spinner_index]
		return string.format("%s AI (%d)", spinner, query_state.active_queries)
	end
	return ""
end

return M