local M = {}

local ExtmarkKind = {
	UNCOVERED = 0,
	PARTIAL = 1,
	COVERED = 2,
}

---@type TarpOpts
local default_opts = {
	enable = true,
	auto_load = true,
	auto_update = true,

	report_dir = nil,
	report_name = "tarpaulin-report.json",

	commands = {
		enable = true,
		test_command = "cargo tarpaulin",
	},

	signs = {
		enable = true,
		covered = {
			sign_hl_group = "TarpCovered",
			sign_text = "▌",
			right_gravity = false,
			spell = false,
			conceal = "",
			priority = 10,
		},
		uncovered = {
			sign_hl_group = "TarpUncovered",
			sign_text = "▌",
			right_gravity = false,
			spell = false,
			conceal = "",
			priority = 10,
		},
		partial = {
			sign_hl_group = "TarpPartial",
			sign_text = "▌",
			right_gravity = false,
			spell = false,
			conceal = "",
			priority = 10,
		},
	},

	highlights = {
		enable = true,
		covered = {
			name = "TarpCovered",
			highlight = {
				fg = "#1d252d",
			},
		},
		uncovered = {
			name = "TarpUncovered",
			highlight = {
				fg = "#261d28",
			},
		},
		partial = {
			name = "TarpPartial",
			highlight = {
				fg = "#272592",
			},
		},
	},

	notifications = {
		enable = true,
		max_lines = 12,
		max_width = 32,
		timeout = 5000,
	},

	diagnostics = {
		enable = true,
		severity = vim.diagnostic.severity.HINT,
	},
}

-- Private members

---@type TarpOpts
M._opts = {}
---@type table<string, ProjectCoverage>
M._coverage = {}
M._namespace = nil
---@type Extmarks
M._extmarks = {}
M._hidden = false
---@type NotificationWindow
M._notification = {
	lines = {},
	buf = nil,
	window = nil,
}

local split_by_newline = function (str)
	local lines = {}
	for line in str:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end
	return lines
end

---@class RootStart
---@field bufnr? integer
---@field file? string

---Finds the first directory containing a `Cargo.toml` file, going up the file tree until it hits root.
---If the starting file or buffer is not specified, uses the currently active buffer.
---@param start? RootStart
---@return string?
M._get_cargo_root = function(start)
	local current_path = nil
	if start and start.bufnr and start.file then
		error("Specify either a buffer number or file.")
	end
	if start and start.bufnr then
		current_path = vim.api.nvim_buf_get_name(start.bufnr)
	elseif start and start.file then
		---@type string
		local file = start.file
		current_path = file
	else
		local bufnr = vim.api.nvim_get_current_buf()
		current_path = vim.api.nvim_buf_get_name(bufnr)
	end

	local current_dir = vim.fn.fnamemodify(current_path, ":p")

	while current_dir ~= "/" do
		local cargo_toml = current_dir .. "/Cargo.toml"
		if vim.fn.filereadable(cargo_toml) == 1 then
			return current_dir
		end
		current_dir = vim.fn.fnamemodify(current_dir, ":h")
	end
end

---Reads the tarpaulin coverage report
---@param start? RootStart
---@return RawCoverageReport?
M._read_coverage_report = function(start)
	local cargo_root = M._get_cargo_root(start)
	if not cargo_root then
		return nil
	end
	local report_dir = M._opts.report_dir
	if not report_dir then
		report_dir = cargo_root
	else
		report_dir = cargo_root .. "/" .. report_dir
	end

	local report_path = report_dir .. "/" .. M._opts.report_name
	local success, f = pcall(io.open, report_path, "r")
	if not success then
		return nil
	end
	if not f then
		return nil
	end
	local report_str = f:read("*a")
	f:close()

	local success, result = pcall(vim.json.decode, report_str, { object = true, array = true })
	if not success then
		return nil
	end

	---@type RawCoverageReport
	local report = result
	return report
end

---@param cargo_root string
M._init_signs = function(cargo_root)
	local project_coverage = M._coverage[cargo_root]
	local bufnr = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(bufnr)
	local coverage = project_coverage.files[file]
	if not coverage then
		return
	end
	for _, covered_line in ipairs(coverage.covered_lines) do
		local id = vim.api.nvim_buf_set_extmark(bufnr, M._namespace, covered_line - 1, 0, M._opts.signs.covered)
		if not M._extmarks[cargo_root] then
			M._extmarks[cargo_root] = {}
		end
		if not M._extmarks[cargo_root][file] then
			M._extmarks[cargo_root][file] = {}
		end
		M._insert_extmark(cargo_root, file, { id = id, bufnr = bufnr, kind = ExtmarkKind.COVERED })
	end

	for _, uncovered_line in ipairs(coverage.uncovered_lines) do
		local id = vim.api.nvim_buf_set_extmark(bufnr, M._namespace, uncovered_line - 1, 0, M._opts.signs.uncovered)
		if not M._extmarks[cargo_root] then
			M._extmarks[cargo_root] = {}
		end
		if not M._extmarks[cargo_root][file] then
			M._extmarks[cargo_root][file] = {}
		end
		M._insert_extmark(cargo_root, file, { id = id, bufnr = bufnr, kind = ExtmarkKind.UNCOVERED })
	end
end

M._clear = function(clear_opts)
	if clear_opts then
		M._opts = vim.deepcopy(default_opts, true)
	end
	M._coverage = {}
	M._hidden_extmarks = {}
	M._extmarks = {}
	M._hidden = false
end

---Converts a highlight group into an extmark kind
---@param sign_hl_group string
---@return integer?
M._extmark_kind = function(sign_hl_group)
	if sign_hl_group == M._opts.signs.uncovered.sign_hl_group then
		return ExtmarkKind.UNCOVERED
	elseif sign_hl_group == M._opts.signs.partial.sign_hl_group then
		return ExtmarkKind.PARTIAL
	elseif sign_hl_group == M._opts.signs.covered.sign_hl_group then
		return ExtmarkKind.COVERED
	end
end

---Gets the correct extmark options based on the supplied kind
---@param kind integer
---@return vim.api.keyset.set_extmark?
M._get_extmark_opts = function(kind)
	if kind == ExtmarkKind.UNCOVERED then
		return M._opts.signs.uncovered
	elseif kind == ExtmarkKind.PARTIAL then
		return M._opts.signs.partial
	elseif kind == ExtmarkKind.COVERED then
		return M._opts.signs.covered
	end
end

M._on_enter = function()
	local cargo_root = M._get_cargo_root()
	if not cargo_root then
		return
	end

	local coverage = M.coverage()
	if not coverage then
		return
	end

	M._coverage[cargo_root] = coverage
	if not M._opts.signs.enable then
		return
	end
	M._init_signs(cargo_root)
end

---Inserts an extmark into the extmark table
---@param cargo_root string
---@param file string
---@param extmark ExtmarkInfo
M._insert_extmark = function(cargo_root, file, extmark)
	if not M._extmarks[cargo_root] then
		M._extmarks[cargo_root] = {}
	end
	if not M._extmarks[cargo_root][file] then
		M._extmarks[cargo_root][file] = {}
	end

	table.insert(M._extmarks[cargo_root][file], extmark)
end

M._create_notification_window = function ()
	if M._notification.buf then
		return
	end
	if M._notification.window then
		return
	end
	local win_width = vim.api.nvim_win_get_width(0)
	local win_height = vim.api.nvim_win_get_height(0)
	local buf = vim.api.nvim_create_buf(false, true)

	local opts = {
		relative = "editor",
		width = M._opts.notifications.max_width,
		height = M._opts.notifications.max_lines,
		row = win_height - M._opts.notifications.max_lines,
		col = win_width - M._opts.notifications.max_width,
		anchor = "NW",
		style = "minimal",
		focusable = false,
		zindex = 50,
		-- border = "single", disabled, but very useful for debugging
	}

	local win = vim.api.nvim_open_win(buf, false, opts)
	vim.api.nvim_set_option_value("winblend", 100, { win = win })
	vim.api.nvim_buf_add_highlight(buf, -1, "WarningMsg", 0, 0, -1)

	M._notification.window = win
	M._notification.buf = buf
	M._notification.lines = {}
	for _ = 1, M._opts.notifications.max_lines do
		table.insert(M._notification.lines, "")
	end
end


---@param message string
M._print_notification_message = function (message)
	table.insert(M._notification.lines, message)

	if #M._notification.lines > M._opts.notifications.max_lines then
		table.remove(M._notification.lines, 1)
	end

	vim.api.nvim_buf_set_lines(M._notification.buf, 0, -1, true, M._notification.lines)

	for i = 0, #M._notification.lines - 1 do
		vim.api.nvim_buf_add_highlight(M._notification.buf, M._namespace, "WarningMsg", i, 0, -1)
	end
end

---sets the expiration for the notification window
---@param ms integer
M._expire_notification_window = function (ms)
	vim.defer_fn(function ()
		vim.api.nvim_win_close(M._notification.window, true)
		vim.api.nvim_buf_delete(M._notification.buf, {force = true})
		M._notification.window = nil
		M._notification.buf = nil
		M._notification.lines = {}
		for _ = 1, M._opts.notifications.max_lines do
			table.insert(M._notification.lines, "")
		end
	end, ms)
end

-- Public API

---@param opts? TarpOpts
M.setup = function(opts)
	M._opts = vim.deepcopy(default_opts, true)
	if opts then
		for key, value in pairs(opts) do
			M._opts[key] = value
		end
	end
	M._namespace = vim.api.nvim_create_namespace("")
	if not M._opts.enable then
		return
	end
	if not M._opts.highlights.enable then
		return
	end

	vim.api.nvim_set_hl(M._namespace, M._opts.highlights.covered.name, M._opts.highlights.covered.highlight)
	vim.api.nvim_set_hl(M._namespace, M._opts.highlights.partial.name, M._opts.highlights.partial.highlight)
	vim.api.nvim_set_hl(M._namespace, M._opts.highlights.uncovered.name, M._opts.highlights.uncovered.highlight)
	vim.api.nvim_set_hl_ns(M._namespace)

	if not M._opts.auto_load then
		return
	end

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
		pattern = { "*.rs" },
		callback = M._on_enter,
	})

	vim.api.nvim_create_user_command("TarpToggle", function()
		M.toggle_coverage()
	end, {
		desc = "Toggle coverage visualization",
	})

	vim.api.nvim_create_user_command("TarpShow", function()
		M.show_coverage()
	end, {
		desc = "Show coverage visualization",
	})

	vim.api.nvim_create_user_command("TarpHide", function()
		M.hide_coverage()
	end, {
		desc = "Hide coverage visualization",
	})

	vim.api.nvim_create_user_command("TarpTest", function()
		local cargo_root = M._get_cargo_root()
		if not cargo_root then
			return
		end
		M.run_tests(cargo_root)
	end, {
		desc = "Run tarpaulin tests",
	})
end

---Shows any hidden signs
M.show_coverage = function()
	-- Re-insert existing extmarks
	for cargo_root, _ in pairs(M._coverage) do
		if not M._extmarks[cargo_root] then
			M._extmarks[cargo_root] = {}
		end
		for file, _ in pairs(M._extmarks[cargo_root]) do
			if not M._extmarks[cargo_root][file] then
				M._extmarks[cargo_root][file] = {}
			end
			for _, extmark in ipairs(M._extmarks[cargo_root][file]) do
				if extmark.id then
					-- Extmark is already visible
					goto continue
				end
				local opts = M._get_extmark_opts(extmark.kind)
				if not opts then
					goto continue
				end
				local id = vim.api.nvim_buf_set_extmark(extmark.bufnr, M._namespace, extmark.line, extmark.col, opts)
				M._insert_extmark(cargo_root, file, { bufnr = extmark.bufnr, id = id, kind = extmark.kind })
				::continue::
			end
		end
	end
	M._hidden = false
end

---Hides any visible signs
M.hide_coverage = function()
	-- Remove existing extmarks
	for cargo_root, _ in pairs(M._coverage) do
		if not M._extmarks[cargo_root] then
			M._extmarks[cargo_root] = {}
		end
		for file, _ in pairs(M._extmarks[cargo_root]) do
			if not M._extmarks[cargo_root][file] then
				M._extmarks[cargo_root][file] = {}
			end
			for _, extmark in ipairs(M._extmarks[cargo_root][file]) do
				if not extmark.id then
					-- Already hidden
					goto continue
				end
				local extmark_info =
					vim.api.nvim_buf_get_extmark_by_id(extmark.bufnr, M._namespace, extmark.id, { details = true })
				if not extmark_info then
					goto continue
				end

				local line = extmark_info[1]
				local col = extmark_info[2]
				local details = extmark_info[3]

				if not details then
					goto continue
				end

				vim.api.nvim_buf_del_extmark(extmark.bufnr, M._namespace, extmark.id)

				extmark.id = nil
				extmark.line = line
				extmark.col = col
				::continue::
			end
		end
	end
	M._hidden = true
end

---Runs tests at the specified `cargo_root`
---@param cargo_root string
M.run_tests = function(cargo_root)
	local on_output = function (_, data) end
	if M._opts.notifications.enable then
		M._create_notification_window()

		on_output = function (_, data)
			if data then
				for _, large_message in ipairs(data) do
					local lines = split_by_newline(large_message)
					for _, message in ipairs(lines) do
						if string.sub(message, 1, 2) == "||" then
							M._print_notification_message(message)
						end
					end
				end
			end
		end
	end

	vim.fn.jobstart(M._opts.commands.test_command, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = on_output,
		on_stderr = on_output,
		on_exit = function(_, exit_code)
			vim.schedule(function()
				if M._opts.notifications.enable then
					M._print_notification_message(string.format("Testing completed with code: %d", exit_code))
					M._expire_notification_window(M._opts.notifications.timeout)
				end
				M._clear(false)
				local coverage = M.coverage({ file = cargo_root })
				if not coverage then
					return
				end

				M._coverage[cargo_root] = coverage
				if not M._opts.signs.enable then
					return
				end
				M._init_signs(cargo_root)
			end)
		end,
		cwd = cargo_root,
	})
end

---Returns information about coverage for the given project, or the current buffer
---@param opts? CoverageOpts
---@return ProjectCoverage?
M.coverage = function(opts)
	local bufnr = nil
	local file = nil
	if opts then
		bufnr = opts.bufnr or bufnr
		file = opts.file or file
	end

	local raw_report = M._read_coverage_report({ bufnr = bufnr, file = file })
	if not raw_report then
		return nil
	end

	local files = {}

	for _, value in ipairs(raw_report.files) do
		local uncovered_lines = {}
		local covered_lines = {}

		for _, trace in ipairs(value.traces) do
			if trace.stats.Line == 0 then
				table.insert(uncovered_lines, trace.line)
			else
				table.insert(covered_lines, trace.line)
			end
		end

		---@type Coverage
		local coverage = {
			covered = value.covered,
			lines = value.coverable,
			coverage = value.covered / value.coverable * 100.0,
			uncovered_lines = uncovered_lines,
			covered_lines = covered_lines,
		}

		local file_name = "/" .. table.concat(value.path, "/", 2)
		files[file_name] = coverage
	end

	---@type ProjectCoverage
	local project_coverage = {
		coverage = raw_report.coverage,
		covered = raw_report.covered,
		lines = raw_report.coverable,
		files = files,
	}

	return project_coverage
end

M.toggle_coverage = function()
	if not M._hidden then
		M.hide_coverage()
	else
		M.show_coverage()
	end
end

return M
