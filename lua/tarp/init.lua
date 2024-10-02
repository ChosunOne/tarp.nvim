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
---@type Extmarks
M._hidden_extmarks = {}
M._hidden = false

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
		table.insert(M._extmarks[cargo_root][file], { id = id, bufnr = bufnr, kind = ExtmarkKind.COVERED })
	end

	for _, uncovered_line in ipairs(coverage.uncovered_lines) do
		local id = vim.api.nvim_buf_set_extmark(bufnr, M._namespace, uncovered_line - 1, 0, M._opts.signs.uncovered)
		if not M._extmarks[cargo_root] then
			M._extmarks[cargo_root] = {}
		end
		if not M._extmarks[cargo_root][file] then
			M._extmarks[cargo_root][file] = {}
		end
		table.insert(M._extmarks[cargo_root][file], { id = id, bufnr = bufnr, kind = ExtmarkKind.UNCOVERED })
	end
end

M._clear = function()
	M._opts = vim.deepcopy(default_opts, true)
	M._coverage = {}
	M._hidden_extmarks = {}
	M._extmarks = {}
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

M._show_signs = function()
	-- Re-insert existing extmarks
	for cargo_root, _ in pairs(M._coverage) do
		if not M._hidden_extmarks[cargo_root] then
			M._hidden_extmarks[cargo_root] = {}
		end
		for file, _ in pairs(M._hidden_extmarks[cargo_root]) do
			if not M._hidden_extmarks[cargo_root][file] then
				M._hidden_extmarks[cargo_root][file] = {}
			end
			for _, extmark in ipairs(M._hidden_extmarks[cargo_root][file]) do
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
	M._hidden_extmarks = {}
end

M._hide_signs = function()
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

				if not M._hidden_extmarks[cargo_root] then
					M._hidden_extmarks[cargo_root] = {}
				end
				if not M._hidden_extmarks[cargo_root][file] then
					M._hidden_extmarks[cargo_root][file] = {}
				end

				local kind = M._extmark_kind(details.sign_hl_group)
				if not kind then
					goto continue
				end

				table.insert(
					M._hidden_extmarks[cargo_root][file],
					{ bufnr = extmark.bufnr, line = line, col = col, kind = kind }
				)
				::continue::
			end
			M._extmarks[cargo_root][file] = {}
		end
	end
	M._extmarks = {}
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
end

M.run_tests = function()
	error("Not yet implemented")
end

---Returns information about coverage for the given file, buffer, or project
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
		M._hide_signs()
	else
		M._show_signs()
	end

	M._hidden = not M._hidden
end

return M
