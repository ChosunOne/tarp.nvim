# Overview
Tarp is a neovim plugin to help display coverage from tarpaulin coverage reports.

The basic idea is that in the left gutter you will see:
    - Red for uncovered lines
    - Yellow for partially covered lines (if statements)
    - Green for covered lines

At the top of each file, you will see an informational diagnostic that is present when there are uncovered lines,
as well as the number of covered lines in the file, and the percentage coverage

```
H: Uncovered lines in file.
H: 586 / 817, 71.73% coverage
```

In addition, while editing code, the lines in the gutter should be preserved as much as possible.  At first, this
simply means when adding new lines the gutter should adjust so that previous covered lines still retain that information.
Later, some syntax analysis should be done to see if the new changes would change coverage (such as adding an if statement
or new function call).

# Commands
There are some commands that tarp should add as well.  Primarily, tarp should have a command to run tests with coverage. 

```
:TarpTest
```

and ideally would execute this when saving the document

# API
The public API should provide methods to get the coverage information.
```lua
local tarp = require("tarp")
tarp.coverage({ file = "mod.rs"}) -- returns a `Coverage` table: { covered: 586, lines: 817, uncovered_lines: {1, 4, 9, ... , 481}}
tarp.coverage({ buffer = 0 }) -- returns a `Coverage` table for the given file open in the indicated buffer
tarp.coverage() -- returns a table of `Coverage` tables for the open projects: { files: { "mod.rs": Coverage, "index.rs": Coverage, ... }}
```

# Configuration
There should be a way to configure which features `tarp` should enable when collecting coverage information, and where it should look to find
coverage information.
tarp.toml

```toml
[coverage]
features = ["debug"]
report-dir = ".coverage"
```
