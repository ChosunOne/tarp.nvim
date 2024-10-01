local M = {}

local default_opts = {
	enable = true,
	auto_load = true,
	auto_update = true,

	report_dir = nil,
	report_name = "tarpaulin-report.json",

	signs = {
		enable = true,
		priority = 10,
		covered = { text = "|" },
		uncovered = { text = "|" },
		partial = { text = "|" },
	},

	commands = {
		enable = true,
		test_command = "cargo tarpaulin",
	},

	highlights = {
		enable = true,
		covered = "TarpCovered",
		uncovered = "TarpUncovered",
		partial = "TarpPartial",
	},

	diagnostics = {
		enable = true,
		severity = vim.diagnostic.severity.HINT,
	},
}

-- Private members

M._opts = default_opts
M._coverage = {}
M._namespace = nil
M._cargo_root = nil

---@class RootStart
---@field bufnr? integer
---@field file? string

---Finds the first directory containing a `Cargo.toml` file, going up the file tree until it hits root.
---If the starting file or buffer is not specified, uses the currently active buffer.
---@param start? RootStart
---@return string|nil
M._get_cargo_root = function(start)
	local current_path = nil
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
---@return RawCoverageReport
M._read_coverage_report = function(start)
	local report_dir = M._opts.report_dir
	if not report_dir then
		report_dir = M._get_cargo_root(start)
	end

	local report_path = report_dir .. "/" .. M._opts.report_name
	local f = io.open(report_path, "r")
	if not f then
		error("File not found: " .. report_path)
	end
	local report_str = f:read("*a")
	f:close()

	local success, result = pcall(vim.json.decode, report_str, { object = true, array = true })
	if not success then
		error("Failed to parse JSON: " .. result)
	end

	---@type RawCoverageReport
	local report = result
	return report
end

M._clear = function()
	M._opts = vim.deepcopy(default_opts, true)
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
end

---Returns information about coverage for the given file, buffer, or project
---@param opts? CoverageOpts
---@return Coverage|ProjectCoverage
M.coverage = function(opts)
	error("Not yet implemented")
end

return M
