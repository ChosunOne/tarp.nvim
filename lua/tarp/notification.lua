---@class Notification

local M = {}

---@type NotificationOpts
M._opts = {}
M._timer = nil
M._throbber_frame = 1
M._is_throbbing = false
M._lines = {}
M._buf = nil
M._window = nil
---@type Highlight?
M._hl = nil
M._ns_id = nil
local throbber = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

M._render_text = function()
	vim.schedule(function()
		vim.api.nvim_buf_set_lines(M._buf, 0, -1, true, M._lines)
		if M._hl then
			for i = 0, #M._lines - 1 do
				vim.api.nvim_buf_add_highlight(M._buf, M._ns_id, M._hl.name, i, 0, -1)
				vim.api.nvim_win_set_hl_ns(M._window, M._ns_id)
			end
		end
	end)
end

M._update_throbber = function()
	if not M._is_throbbing then
		return
	end

	local throbber_frame_offset = #throbber[M._throbber_frame] + 1
	local new_frame = M._lines[M._opts.max_lines]:sub(1, -throbber_frame_offset) .. throbber[M._throbber_frame]
	M._lines[M._opts.max_lines] = new_frame
	M._throbber_frame = (M._throbber_frame % #throbber) + 1
	M._render_text()
end

---Creates the notification window
---@param message? string
M._create_window = function(message)
	vim.schedule(function()
		if M._buf then
			return
		end
		if M._window then
			return
		end
		local win_width = vim.api.nvim_win_get_width(0)
		local win_height = vim.api.nvim_win_get_height(0)
		local buf = vim.api.nvim_create_buf(false, true)

		local opts = {
			relative = "editor",
			width = M._opts.max_width,
			height = M._opts.max_lines,
			row = win_height - M._opts.max_lines,
			col = win_width - M._opts.max_width,
			anchor = "NW",
			style = "minimal",
			focusable = false,
			zindex = 50,
			-- border = "single", disabled, but very useful for debugging
		}

		local win = vim.api.nvim_open_win(buf, false, opts)
		vim.api.nvim_set_option_value("winblend", 100, { win = win })

		M._window = win
		M._buf = buf
		M._lines = {}
		for _ = 1, M._opts.max_lines do
			table.insert(M._lines, "")
		end
		if message then
			table.insert(M._lines, message)
		end
		if #M._lines > M._opts.max_lines then
			table.remove(M._lines, 1)
		end
	end)
end

-- Public API

---Setup notifications
---@param opts NotificationOpts
---@param hl? Highlight
---@param ns_id? integer
M.setup = function(opts, hl, ns_id)
	M._opts = opts
	M._hl = hl
	M._ns_id = ns_id
	M.clear()
end

M.clear = function()
	M.expire_window(0)
end

---@param message string
M.print_message = function(message)
	if not M._window and not M._buf then
		M._create_window(message)
	end

	vim.schedule(function()
		table.insert(M._lines, M._opts.max_lines - 1, message)

		if #M._lines > M._opts.max_lines then
			table.remove(M._lines, 1)
		end
		M._render_text()
	end)
end

M.start_throbber = function(message)
	if M._is_throbbing then
		return
	end

	if not M._window and not M._buf then
		M._create_window(message)
	end

	vim.schedule(function()
		M._throbber_frame = 1

		local line = M._lines[#M._lines] .. " " .. throbber[M._throbber_frame]
		M._lines[#M._lines] = line

		M._timer = vim.loop.new_timer()
		M._timer:start(0, 100, vim.schedule_wrap(M._update_throbber))
		M._is_throbbing = true
	end)
end

M.stop_throbber = function()
	if not M._is_throbbing then
		return
	end

	if not M._window and not M._buf then
		M._create_window()
	end

	M._is_throbbing = false

	if M._timer then
		M._timer:stop()
		M._timer:close()
		M._timer = nil
	end

	M._lines[M._opts.max_lines] = ""
end

---sets the expiration for the notification window
---@param ms integer
M.expire_window = function(ms)
	vim.defer_fn(function()
		if M._is_throbbing then
			M.stop_throbber()
		end
		if M._window then
			vim.api.nvim_win_close(M._window, true)
			M._window = nil
		end
		if M._buf then
			vim.api.nvim_buf_delete(M._buf, { force = true })
			M._buf = nil
		end
		M._lines = {}
		M._throbber_frame = 1
		for _ = 1, M._opts.max_lines do
			table.insert(M._lines, "")
		end
	end, ms)
end

return M
