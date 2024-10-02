require("tarp.globals")
local Path = require("plenary.path")

local get_current_path = function()
	return Path:new():absolute() .. "tests"
end

local count_array = function(tbl)
	local count = 0
	for _, _ in ipairs(tbl) do
		count = count + 1
	end

	return count
end

local count_table = function(tbl)
	local count = 0
	for _, _ in pairs(tbl) do
		count = count + 1
	end

	return count
end

describe("tarp", function()
	before_each(function()
		require("tarp")._clear(true)
	end)

	it("can be required", function()
		require("tarp")
	end)

	it("can run setup", function()
		local tarp = require("tarp")
		tarp.setup()

		local covered = vim.api.nvim_get_hl(tarp._namespace, { name = tarp._opts.highlights.covered.name })
		assert.is_not.Nil(covered)
	end)

	it("can clear settings", function()
		local tarp = require("tarp")
		tarp.setup({ enable = false })
		assert.are.same(false, tarp._opts.enable)
		tarp._clear(true)
		assert.are.same(true, tarp._opts.enable)
	end)

	it("can get the cargo root", function()
		local tarp = require("tarp")
		local current_path = get_current_path()
		local root = tarp._get_cargo_root({ file = current_path .. "/test_rust_project" })
		assert.are.same(current_path .. "/test_rust_project/", root)
	end)

	it("can read a tarpaulin coverage report", function()
		local tarp = require("tarp")
		local current_path = get_current_path()
		tarp.setup({ report_dir = ".coverage" })
		local report = tarp._read_coverage_report({ file = current_path .. "/test_rust_project" })
		assert.are.same(report.coverage, 70)
		assert.are.same(report.coverable, 10)
		assert.are.same(report.covered, 7)
		local file_count = count_array(report.files)
		assert.are.same(file_count, 2)
		local file_1 = report.files[1]
		assert.are.same(file_1.coverable, 2)
		assert.are.same(file_1.covered, 1)
		local path = "/" .. table.concat(file_1.path, "/", 2)
		assert.are.same(current_path .. "/test_rust_project/src/lib.rs", path)
		assert.is_not.Nil(file_1.content)
		local trace_1 = file_1.traces[1]
		assert.are.same(trace_1.line, 1)
		assert.are.same(trace_1.length, 1)
		assert.are.same(trace_1.stats.Line, 2)
		local address_count = count_array(trace_1.address)
		assert.are.same(address_count, 3)
		local trace_2 = file_1.traces[2]
		assert.are.same(trace_2.line, 2)
		assert.are.same(trace_2.length, 1)
		assert.are.same(trace_2.stats.Line, 0)
		address_count = count_array(trace_2.address)
		assert.are.same(address_count, 2)

		local file_2 = report.files[2]
		local trace_3 = file_2.traces[1]
		assert.are.same(trace_3.line, 1)
		assert.are.same(trace_3.length, 1)
		assert.are.same(trace_3.stats.Line, 3)
		address_count = count_array(trace_3.address)
		assert.are.same(address_count, 2)
		local trace_4 = file_2.traces[4]
		assert.are.same(trace_4.line, 4)
		assert.are.same(trace_4.length, 1)
		assert.are.same(trace_4.stats.Line, 1)
		address_count = count_array(trace_4.address)
		assert.are.same(address_count, 1)
	end)

	it("can get project coverage", function()
		local tarp = require("tarp")
		local current_path = get_current_path()
		local cargo_root = tarp._get_cargo_root({ file = current_path .. "/test_rust_project" })
		tarp.setup({ report_dir = ".coverage" })
		local project_coverage = tarp.coverage({ file = cargo_root })
		assert.is_not.Nil(project_coverage)

		assert.are.same(project_coverage.coverage, 70)
		assert.are.same(project_coverage.covered, 7)
		assert.are.same(project_coverage.lines, 10)
		local file_count = count_table(project_coverage.files)
		assert.are.same(file_count, 2)

		local main_path = cargo_root .. "src/main.rs"
		local coverage = project_coverage.files[main_path]
		assert.is_not.Nil(coverage)
		assert.are.same(coverage.coverage, 75)
		assert.are.same(coverage.covered, 6)
		assert.are.same(coverage.lines, 8)
		assert.are.same(coverage.uncovered_lines, { 13, 14 })
		assert.are.same(coverage.covered_lines, { 1, 2, 3, 4, 8, 9 })

		local lib_path = cargo_root .. "src/lib.rs"
		coverage = project_coverage.files[lib_path]
		assert.is_not.Nil(coverage)
		assert.are.same(coverage.coverage, 50)
		assert.are.same(coverage.covered, 1)
		assert.are.same(coverage.lines, 2)
		assert.are.same(coverage.uncovered_lines, { 2 })
		assert.are.same(coverage.covered_lines, { 1 })
	end)

	it("can toggle displaying coverage", function()
		local tarp = require("tarp")
		local with = require("plenary.context_manager").with
		local open = require("plenary.context_manager").open
		local current_path = get_current_path()
		local cargo_root = current_path .. "/test_rust_project"
		local file_text = with(open(cargo_root .. "/src/main.rs"), function(reader)
			return reader:read("*a")
		end)
		local paste = function()
			vim.api.nvim_paste(file_text, true, -1)
		end
		tarp.setup({ report_dir = ".coverage" })

		local buffer = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(buffer, cargo_root .. "/src/main.rs")
		vim.api.nvim_buf_call(buffer, paste)
		vim.api.nvim_buf_call(buffer, tarp._on_enter)

		local og_extmarks = vim.deepcopy(tarp._extmarks)

		vim.api.nvim_buf_call(buffer, tarp.toggle_coverage)
		assert(tarp._hidden)
		vim.api.nvim_buf_call(buffer, tarp.toggle_coverage)
		assert.is_not(tarp._hidden)

		local extmark_count = count_table(og_extmarks[cargo_root][cargo_root .. "/src/main.rs"])
		assert.are.same(extmark_count, 8)
	end)
end)
