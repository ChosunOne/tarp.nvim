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

describe("tarp", function()
	before_each(function()
		require("tarp")._clear()
	end)

	it("can be required", function()
		require("tarp")
	end)

	it("can clear settings", function()
		local tarp = require("tarp")
		tarp.setup({ enable = false })
		assert.are.same(false, tarp._opts.enable)
		tarp._clear()
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
		tarp.setup({ report_dir = current_path .. "/test_rust_project/.coverage" })
		local report = tarp._read_coverage_report()
		assert.are.same(report.coverage, 100)
		assert.are.same(report.coverable, 4)
		assert.are.same(report.covered, 4)
		local file_count = count_array(report.files)
		assert.are.same(file_count, 1)
		local file = report.files[1]
		assert.are.same(file.coverable, 4)
		assert.are.same(file.covered, 4)
		local path = "/" .. table.concat(file.path, "/", 2)
		assert.are.same(current_path .. "/test_rust_project/src/main.rs", path)
		assert.is_not.Nil(file.content)
		local trace_1 = file.traces[1]
		assert.are.same(trace_1.line, 1)
		assert.are.same(trace_1.length, 1)
		assert.are.same(trace_1.stats.Line, 3)
		local address_count = count_array(trace_1.address)
		assert.are.same(address_count, 3)
		local trace_2 = file.traces[2]
		assert.are.same(trace_2.line, 2)
		assert.are.same(trace_2.length, 1)
		assert.are.same(trace_2.stats.Line, 1)
		address_count = count_array(trace_2.address)
		assert.are.same(address_count, 1)
		local trace_3 = file.traces[3]
		assert.are.same(trace_3.line, 5)
		assert.are.same(trace_3.length, 1)
		assert.are.same(trace_3.stats.Line, 1)
		address_count = count_array(trace_3.address)
		assert.are.same(address_count, 1)
		local trace_4 = file.traces[4]
		assert.are.same(trace_4.line, 6)
		assert.are.same(trace_4.length, 1)
		assert.are.same(trace_4.stats.Line, 1)
		address_count = count_array(trace_4.address)
		assert.are.same(address_count, 1)
	end)
end)
