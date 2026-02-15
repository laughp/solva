# solva.nvim

[![CI](https://github.com/laughp/solva/actions/workflows/ci.yml/badge.svg)](https://github.com/laughp/solva/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

`solva.nvim` brings line-by-line calculation to Neovim.

This project is heavily inspired by the [Soulver Mac app](https://soulver.app/).

Write expressions in a normal text buffer, then see results update in a right-side split (or inline virtual text). It supports variables, units, running totals, line references like `line3`, and common math functions.

## Highlights

- Fast line-by-line evaluation in plain text buffers
- Right-side results split (`result_mode = "split"`) or inline virtual text
- Variables with `$` syntax: `$rent = 2400`, then `$rent * 12`
- Previous result references: `ans`, `_`
- Line references: `line1`, `line2`, `line3`, ...
- Running totals: `total`, `subtotal`, `total in usd`
- Unit and temperature conversion: `10 km in mi`, `72 f in c`
- Date math: `today + 3 weeks 2 days`, `from March 12 to July 30`
- Time math: `3:35 am + 9 hours 20 minutes`, `from 9:15 am to 5:40 pm`
- Functions: `sqrt`, `abs`, `floor`, `ceil`, `round`, `log`, `ln`, `sin`, `cos`, `tan`, `gcf(...)`
- Continuous auto-eval while typing (scoped to specific filetypes or enabled per-buffer)

## Install (lazy.nvim)

```lua
{
  dir = "~/path/to/solva.nvim",
  name = "solva_nvim",
  config = function()
    require("solva").setup({
      precision = 6,
      result_prefix = "",
      highlight_group = "Comment",
      result_mode = "split", -- "split" | "virtual_text"
      split_width = 36,

      auto_eval = true,
      auto_eval_debounce_ms = 120,
      auto_eval_filetypes = { "solva" }, -- auto-run only on these filetypes
    })
  end,
}
```

## Quick Start

1. Open a buffer and set `:set filetype=solva` (or use `:SolvaEnable` in any buffer).
2. Type:

```text
$subtotal = 129.99
$tax = 8.25%
$subtotal + $subtotal * $tax
ans * 0.9
line3 * 2

10 km in mi
72 f in c
today + 3 weeks 2 days
from March 12 to July 30
3:35 am + 9 hours 20 minutes
from 9:15 am to 5:40 pm

Lunch: 14.50 usd
Coffee: 4.25 usd
total
```

3. Run `:SolvaEvalBuffer` (or rely on auto-eval if enabled).

## Commands

- `:SolvaEvalLine` evaluate current line
- `:SolvaEval` evaluate selected range (visual: `:'<,'>SolvaEval`)
- `:SolvaEvalBuffer` evaluate full buffer
- `:SolvaClear` clear rendered results
- `:SolvaOpenSplit` open the right-side results split
- `:SolvaCloseSplit` close the right-side results split
- `:SolvaEnable` enable Solva for current buffer (auto-eval + split behavior)
- `:SolvaDisable` disable Solva for current buffer and close/clear results

## Expression Guide

### Arithmetic

- Operators: `+ - * / ^`
- Parentheses supported
- Implicit multiplication supported: `2(3+4)`, `10 km`
- Percent postfix: `50%`, `200 + 10%`

### Variables

- Assign with `$name = expr`
- Use with `$name`
- Example:

```text
$hours = 160
$rate = 95
$hours * $rate
```

### Line References

- Any successfully evaluated line is available as `lineN`
- Example:

```text
10
20
line1 + line2
line3 * 2
```

### Running Totals

- `total` and `subtotal` show current running total
- You can convert totals: `total in usd`, `total in eur`
- If value types are incompatible, Solva starts a new subtotal block

### Date Math

Supported date expressions:

- `today + 3 weeks 2 days`
- `2026-03-01 + 45 days`
- `2026-03-01 - 2 weeks`
- `from March 12 to July 30`
- `from 2026-03-01 to 2026-03-15`

Notes:

- `from ... to ...` returns a day count.
- Month-name dates default to the current year when year is omitted.

### Time Math

Supported time expressions:

- `3:35 am + 9 hours 20 minutes`
- `14:10 + 45 min`
- `from 9:15 am to 5:40 pm`

Notes:

- Time output is formatted as `h:mm am/pm`.
- `from ... to ...` returns a duration (for example `8 hours 25 minutes`).

### Units and Conversion

Supported groups:

- Length: `mm cm m km in ft yd mi`
- Mass: `g kg oz lb`
- Time: `s min h day`
- Temperature: `c f k`
- Currency (static placeholders): `usd eur gbp jpy`

Examples:

```text
10 km in mi
5 lb in kg
72 f in c
$100 + 50 usd
€120 + £10
```

### Functions

- `sqrt(x)`
- `abs(x)`
- `floor(x)`
- `ceil(x)`
- `round(x)`
- `log(x)` (base 10)
- `ln(x)` (natural log)
- `sin(x)`, `cos(x)`, `tan(x)`
- `gcf(a, b, c, ...)` greatest common factor for integers

## Configuration

`require("solva").setup({...})` supports:

- `precision` (number, default `6`)
- `max_line_length` (number, default `10000`)
- `max_tokens` (number, default `2048`)
- `max_parse_depth` (number, default `128`)
- `max_lines_per_eval` (number, default `2000`)
- `result_prefix` (string, default `""`)
- `highlight_group` (string, default `"Comment"`)
- `result_mode` (`"split"` or `"virtual_text"`, default `"split"`)
- `split_width` (number, default `36`)
- `auto_eval` (boolean, default `false`)
- `auto_eval_debounce_ms` (number, default `120`)
- `auto_eval_events` (list, default `{ "TextChanged", "TextChangedI", "InsertLeave", "BufEnter" }`)
- `auto_eval_filetypes` (list, default `{ "solva" }`)
- `buffer_enable_var` (string, default `"solva_enabled"`)

## Notes

- Currency rates are static placeholders for local workflow and are not fetched live.
- This is an MVP parser focused on practical inline calculation workflow inside Neovim.

## Testing

Run the regression suite:

```sh
make test
```

Run coverage:

```sh
make coverage-report
```

Current tests cover:

- Core arithmetic and functions
- Variables, `ans`, and `lineN` references
- Units and conversions
- Totals/subtotals and labels
- Date and time math
- Error paths for invalid expressions
