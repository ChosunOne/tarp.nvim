-- See `:help sign_define` for details
---@class SignDefine
---@field icon? string
---@field linehl? string
---@field numhl? string
---@field text? string
---@field texthl? string
---@field culhl? string

---@class SignOpts
---@field enable? boolean
---@field priority? integer
---@field covered? SignDefine
---@field uncovered? SignDefine
---@field partial? SignDefine

---@class CommandOpts
---@field enable? boolean
---@field test_command? string

-- see `:help highlights` for details
---@class HighlightOpts
---@field enable? boolean
---@field covered? string
---@field uncovered? string
---@field partial? string

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
---@field features? string[]
---@field signs? SignOpts
---@field commands? CommandOpts
---@field highlights? HighlightOpts
---@field diagnostics? DiagnosticOpts

---@class CoverageOpts
---@field file? string
---@field bufnr? integer

---@class Coverage
---@field covered integer
---@field lines integer
---@field uncovered_lines integer[]

---@class ProjectCoverage
---@field files table<string, Coverage>

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
