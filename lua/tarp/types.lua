
---@class SignOpts
---@field enable? boolean
---@field priority? integer
---@field covered? vim.api.keyset.set_extmark
---@field uncovered? vim.api.keyset.set_extmark
---@field partial? vim.api.keyset.set_extmark

---@class CommandOpts
---@field enable? boolean
---@field test_command? string

---@class Highlight
---@field name string
---@field highlight vim.api.keyset.highlight

-- see `:help highlights` for details
---@class HighlightOpts
---@field enable? boolean
---@field covered? Highlight
---@field uncovered? Highlight
---@field partial? Highlight

-- see `:help diagnostic-api` for details
---@class DiagnosticOpts
---@field enable? boolean
---@field severity? integer

-- see `:help tarp` for details
---@class TarpOpts
---@field enable? boolean
---@field auto_load? boolean
---@field config_path? string
---@field report_dir? string
---@field report_name? string
---@field features? string[]
---@field signs? SignOpts
---@field commands? CommandOpts
---@field highlights? HighlightOpts
---@field diagnostics? DiagnosticOpts

---@class CoverageOpts
---@field file? string
---@field bufnr? integer

---@class Coverage
---@field coverage number
---@field covered integer
---@field lines integer
---@field uncovered_lines integer[]
---@field covered_lines integer[]

---@class ProjectCoverage
---@field coverage number
---@field covered integer
---@field files table<string, Coverage>
---@field lines integer

---@class RawCoverageStats
---@field Line integer

---@class RawCoverageTrace
---@field address integer[]
---@field length integer
---@field line integer
---@field stats RawCoverageStats

-- The JSON structure which tarpaulin generates
---@class RawCoverageFile
---@field content string
---@field covered integer
---@field coverable integer
---@field path string[]
---@field traces RawCoverageTrace[]

---@class RawCoverageReport
---@field files RawCoverageFile[]
---@field coverage number
---@field covered integer
---@field coverable integer
