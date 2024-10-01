local M = {}

local default_opts = {
	enable = true,
	auto_load = true,
	auto_update = true,

	config_path = nil,
	report_dir = ".coverage",
	features = {},

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
---@param start RootStart
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

---Finds all the rust files attached to the root directory specified by the presence of a `Cargo.toml`
---file.
---@param start RootStart
---@return string[] | nil
M._get_rust_files = function(start)
	local root = M._get_cargo_root(start)
	if not root then
		return nil
	end
	if string.sub(root, -1, -1) == "/" then
		root = string.sub(root, 1, -2)
	end
	local rust_files = {}

	---@param dir string
	local function scan_directory(dir)
		local fs = vim.loop.fs_scandir(dir)
		if not fs then
			return
		end

		while true do
			local name, type = vim.loop.fs_scandir_next(fs)
			if not name then
				break
			end
			local full_path = dir .. "/" .. name
			if type == "directory" then
				scan_directory(full_path)
			elseif type == "file" and name:match("%.rs$") then
				table.insert(rust_files, full_path)
			end
		end
	end

	scan_directory(root)
	return rust_files
end

-- Public API

---@param opts? TarpOpts
M.setup = function(opts)
	M._opts = vim.tbl_deep_extend("force", default_opts, opts or {})
	M._namespace = vim.api.nvim_create_namespace("")
end

---Returns information about coverage for the given file, buffer, or project
---@param opts? CoverageOpts
---@return Coverage|ProjectCoverage
M.coverage = function(opts)
	error("Not yet implemented")
end

return M
