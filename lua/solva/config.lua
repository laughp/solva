local M = {}

M.defaults = {
  result_prefix = "",
  highlight_group = "Comment",
  precision = 6,
  max_line_length = 10000,
  max_tokens = 2048,
  max_parse_depth = 128,
  max_lines_per_eval = 2000,
  result_mode = "split", -- "split" | "virtual_text"
  split_width = 36,
  auto_eval = false,
  auto_eval_debounce_ms = 120,
  auto_eval_events = { "TextChanged", "TextChangedI", "InsertLeave", "BufEnter" },
  auto_eval_filetypes = { "solva" },
  buffer_enable_var = "solva_enabled",
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
