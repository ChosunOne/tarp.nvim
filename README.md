# tarp.nvim
View test coverage in Rust projects

## What is Tarp?
Tarp is a neovim plugin that displays test coverage from [tarpaulin](https://github.com/xd009642/tarpaulin) directly in your editor via the sign gutter.  

![Screenshot_20241002_170841](https://github.com/user-attachments/assets/1b9e31a4-ec5d-4980-8fbc-fd0c16a33221)

## Getting started
Using [vim-plug](https://github.com/junegunn/vim-plug)
```
Plug 'ChosunOne/tarp.nvim'
```

Using [lazy.nvim](https://www.lazyvim.org/)
```lua
-- init.lua:
{
    'ChosunOne/tarp.nvim'
}
```

## Configuration
The style and functionality of Tarp can be customized to suit your needs.  Below are the default configuration options:

```lua
{
	enable = true,
    -- Whether to automatically load coverage information when opening a file
	auto_load = true,
    -- Whether to run tests when changes are made
	auto_update = true,

    -- The directory to search relative to the cargo root path (where `Cargo.toml` is located)
    -- Tarp will search for the nearest parent directory with `Cargo.toml` if not specified
	report_dir = nil,
    -- The name of the file to read for coverage information
	report_name = "tarpaulin-report.json",

	commands = {
		enable = true,
        -- The command to run to generate coverage reports
		test_command = "cargo tarpaulin",
	},

    -- See `:help nvim_buf_set_extmark` for details
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

    -- see `:help highlights` for details
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
```

which can be passed into the `setup` function:
```lua
require("tarp").setup({
    diagnostics = {
        enable = false,
    }
})
```

## Usage
There are four user commands:
- `TarpToggle`: Toggles visibility of coverage information
- `TarpTest`: Runs the specified testing command (defaulting to `cargo tarpaulin`) to collect updated coverage information.
- `TarpShow`: Shows any loaded coverage information in the sign gutter that was previously hidden.
- `TarpHide`: Hides any loaded coverage information in the sign gutter.

`tarpaulin` should be configured to output `JSON` reports, and the `report_dir` and `report_name` for Tarp should be configured to match the generated report artifact.  You can see more information on how to configure the format and location of `tarpaulin` reports in their [documentation](https://github.com/xd009642/tarpaulin?tab=readme-ov-file#tarpaulin).

## API Usage
Tarp also exposes additional information via the public API:
- `tarp.coverage`: Reports information for each file in a cargo project for which coverage information exsists.  See [types.lua](./lua/tarp/types.lua) for more details
- `tarp.toggle_coverage`: Toggles visibility of Tarp sign extmarks
- `tarp.run_tests`: Runs the specified testing command to generate updated coverage information 
- `tarp.show_coverage`: Shows Tarp sign extmarks
- `tarp.hide_coverage`: Hides Tarp sign extmarks
