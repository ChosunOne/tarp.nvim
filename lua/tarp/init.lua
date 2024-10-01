local M = {}

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
		priority = 10,
		covered = {
			sign_hl_group = "TarpCovered",
			sign_text = "▌",
			right_gravity = false,
			spell = false,
		},
		uncovered = {
			sign_hl_group = "TarpUncovered",
			sign_text = "▌",
			right_gravity = false,
			spell = false,
		},
		partial = {
			sign_hl_group = "TarpPartial",
			sign_text = "▌",
			right_gravity = false,
			spell = false,
		},
	},

	highlights = {
		enable = true,
		covered = {
			name = "TarpCovered",
			highlight = {
				-- bg = "#1d252d",
				fg = "#1d252d",
			},
		},
		uncovered = {
			name = "TarpUncovered",
			highlight = {
				-- bg = "#261d28",
				fg = "#261d28",
			},
		},
		partial = {
			name = "TarpPartial",
			highlight = {
				-- bg = "#272592",
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
M._extmarks = {}

---@class RootStart
---@field bufnr? integer
---@field file? string

---Finds the first directory containing a `Cargo.toml` file, going up the file tree until it hits root.
---If the starting file or buffer is not specified, uses the currently active buffer.
---@param start? RootStart
---@return string|nil
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
	local report_dir = M._opts.report_dir
	if not report_dir then
		report_dir = M._get_cargo_root(start)
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
M._show_signs = function(cargo_root)
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
		table.insert(M._extmarks[cargo_root][file], id)
	end

	for _, uncovered_line in ipairs(coverage.uncovered_lines) do
		local id = vim.api.nvim_buf_set_extmark(bufnr, M._namespace, uncovered_line - 1, 0, M._opts.signs.uncovered)
		if not M._extmarks[cargo_root] then
			M._extmarks[cargo_root] = {}
		end
		if not M._extmarks[cargo_root][file] then
			M._extmarks[cargo_root][file] = {}
		end
		table.insert(M._extmarks[cargo_root][file], id)
	end
end

M._clear = function()
	M._opts = vim.deepcopy(default_opts, true)
	M._coverage = {}
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
		callback = function()
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
			M._show_signs(cargo_root)
		end,
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

return M
