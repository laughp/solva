local config = require("solva.config")
local evaluator = require("solva.evaluator")

local M = {}

local ns = vim.api.nvim_create_namespace("solva_nvim")
local split_state = {}
local debounce_state = {}

local function contains(list, value)
  for _, v in ipairs(list or {}) do
    if v == value then
      return true
    end
  end
  return false
end

local function is_buffer_enabled(bufnr)
  local key = config.options.buffer_enable_var
  local ok, value = pcall(function()
    return vim.b[bufnr][key]
  end)
  return ok and value == true
end

local function should_auto_eval(bufnr)
  if is_buffer_enabled(bufnr) then
    return true
  end
  local ft = vim.bo[bufnr].filetype
  return contains(config.options.auto_eval_filetypes, ft)
end

local function set_line_result(bufnr, lnum0, text)
  vim.api.nvim_buf_set_extmark(bufnr, ns, lnum0, 0, {
    virt_text = { { config.options.result_prefix .. text, config.options.highlight_group } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
end

local function sanitize_error(err)
  local s = tostring(err or "")
  s = s:gsub("\n.*", "")
  s = s:gsub("^%s*.-:%d+:%s*", "")
  s = s:gsub("^%s*error:%s*", "")
  if s == "" then
    s = "evaluation failed"
  end
  return s
end

local function empty_lines(count)
  local lines = {}
  for i = 1, count do
    lines[i] = ""
  end
  return lines
end

local function ensure_split_entry(src_bufnr)
  local entry = split_state[src_bufnr]
  if not entry then
    entry = {}
    split_state[src_bufnr] = entry
  end
  if not (entry.result_bufnr and vim.api.nvim_buf_is_valid(entry.result_bufnr)) then
    local result_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(result_bufnr, "Solva Results [" .. src_bufnr .. "]")
    vim.bo[result_bufnr].buftype = "nofile"
    vim.bo[result_bufnr].bufhidden = "wipe"
    vim.bo[result_bufnr].swapfile = false
    vim.bo[result_bufnr].modifiable = false
    vim.bo[result_bufnr].filetype = "solva-results"
    entry.result_bufnr = result_bufnr
    entry.winid = nil
  end
  return entry
end

local function ensure_split_window(src_bufnr)
  local entry = ensure_split_entry(src_bufnr)
  if entry.winid and vim.api.nvim_win_is_valid(entry.winid) then
    return entry
  end

  local src_winid = vim.fn.bufwinid(src_bufnr)
  local current_winid = vim.api.nvim_get_current_win()
  if src_winid ~= -1 then
    vim.api.nvim_set_current_win(src_winid)
  end

  vim.cmd("botright vsplit")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(winid, config.options.split_width)
  vim.api.nvim_win_set_buf(winid, entry.result_bufnr)
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = "no"
  vim.wo[winid].wrap = false
  vim.wo[winid].winfixwidth = true
  vim.wo[winid].cursorline = false
  entry.winid = winid

  if src_winid ~= -1 and vim.api.nvim_win_is_valid(src_winid) then
    vim.api.nvim_set_current_win(src_winid)
  elseif vim.api.nvim_win_is_valid(current_winid) then
    vim.api.nvim_set_current_win(current_winid)
  end

  return entry
end

local function render_split_lines(src_bufnr, start_line1, end_line1, rendered_lines, clear_existing)
  local entry = ensure_split_window(src_bufnr)
  local result_bufnr = entry.result_bufnr
  local src_line_count = vim.api.nvim_buf_line_count(src_bufnr)

  vim.bo[result_bufnr].modifiable = true
  if clear_existing then
    vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, empty_lines(src_line_count))
  else
    local existing = vim.api.nvim_buf_line_count(result_bufnr)
    if existing < src_line_count then
      vim.api.nvim_buf_set_lines(result_bufnr, existing, -1, false, empty_lines(src_line_count - existing))
    elseif existing > src_line_count then
      vim.api.nvim_buf_set_lines(result_bufnr, src_line_count, -1, false, {})
    end
  end

  if end_line1 >= start_line1 then
    vim.api.nvim_buf_set_lines(result_bufnr, start_line1 - 1, end_line1, false, rendered_lines)
  end
  vim.bo[result_bufnr].modifiable = false
end

function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local entry = split_state[bufnr]
  if entry and entry.result_bufnr and vim.api.nvim_buf_is_valid(entry.result_bufnr) then
    vim.bo[entry.result_bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(entry.result_bufnr, 0, -1, false, {})
    vim.bo[entry.result_bufnr].modifiable = false
  end
end

function M.open_split(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  ensure_split_window(bufnr)
end

function M.close_split(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local entry = split_state[bufnr]
  if not entry then
    return
  end
  if entry.winid and vim.api.nvim_win_is_valid(entry.winid) then
    vim.api.nvim_win_close(entry.winid, true)
  end
  entry.winid = nil
end

function M.enable_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.b[bufnr][config.options.buffer_enable_var] = true
end

function M.disable_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.b[bufnr][config.options.buffer_enable_var] = false
end

local function evaluate_lines(bufnr, start_line1, end_line1, clear_existing)
  local requested_end_line1 = end_line1
  local max_lines = config.options.max_lines_per_eval or 2000
  if max_lines < 1 then
    max_lines = 1
  end
  if end_line1 - start_line1 + 1 > max_lines then
    end_line1 = start_line1 + max_lines - 1
  end
  local truncated = requested_end_line1 > end_line1

  local mode = config.options.result_mode
  if clear_existing ~= false and mode == "virtual_text" then
    M.clear(bufnr)
  end

  local ctx = evaluator.new_context()
  if start_line1 > 1 then
    local prior = vim.api.nvim_buf_get_lines(bufnr, 0, start_line1 - 1, false)
    for i, line in ipairs(prior) do
      pcall(evaluator.evaluate_line, line, ctx, {
        precision = config.options.precision,
        line_number = i,
        max_line_length = config.options.max_line_length,
        max_tokens = config.options.max_tokens,
        max_parse_depth = config.options.max_parse_depth,
      })
    end
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line1 - 1, end_line1, false)
  local rendered_lines = {}
  for idx, line in ipairs(lines) do
    local line_number = start_line1 + idx - 1
    local ok, result = pcall(evaluator.evaluate_line, line, ctx, {
      precision = config.options.precision,
      line_number = line_number,
      max_line_length = config.options.max_line_length,
      max_tokens = config.options.max_tokens,
      max_parse_depth = config.options.max_parse_depth,
    })
    local lnum0 = start_line1 + idx - 2
    if ok and result then
      if mode == "virtual_text" then
        set_line_result(bufnr, lnum0, result)
      end
      rendered_lines[idx] = config.options.result_prefix .. result
    elseif not ok then
      local err = "error: " .. sanitize_error(result)
      if mode == "virtual_text" then
        set_line_result(bufnr, lnum0, err)
      end
      rendered_lines[idx] = config.options.result_prefix .. err
    else
      rendered_lines[idx] = ""
    end
  end

  if mode == "split" then
    render_split_lines(bufnr, start_line1, end_line1, rendered_lines, clear_existing ~= false)
    if truncated and #rendered_lines > 0 then
      local last = rendered_lines[#rendered_lines]
      local suffix = " [truncated at " .. tostring(max_lines) .. " lines]"
      rendered_lines[#rendered_lines] = (last == "" and suffix or (last .. suffix))
      render_split_lines(bufnr, start_line1, end_line1, rendered_lines, false)
    end
  elseif clear_existing ~= false then
    local entry = split_state[bufnr]
    if entry and entry.result_bufnr and vim.api.nvim_buf_is_valid(entry.result_bufnr) then
      vim.bo[entry.result_bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(entry.result_bufnr, 0, -1, false, {})
      vim.bo[entry.result_bufnr].modifiable = false
    end
  end
  if truncated and mode == "virtual_text" then
    local lnum0 = end_line1 - 1
    if lnum0 >= 0 then
      set_line_result(bufnr, lnum0, "evaluation truncated at " .. tostring(max_lines) .. " lines")
    end
  end
end

function M.eval_current_line()
  local bufnr = vim.api.nvim_get_current_buf()
  local line1 = vim.api.nvim_win_get_cursor(0)[1]
  evaluate_lines(bufnr, line1, line1)
end

function M.eval_range(start_line1, end_line1)
  local bufnr = vim.api.nvim_get_current_buf()
  evaluate_lines(bufnr, start_line1, end_line1)
end

function M.eval_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local count = vim.api.nvim_buf_line_count(bufnr)
  evaluate_lines(bufnr, 1, count)
end

function M.setup(opts)
  config.setup(opts)
  if config.options.auto_eval then
    local group = vim.api.nvim_create_augroup("SolvaNvimAutoEval", { clear = true })
    vim.api.nvim_create_autocmd(config.options.auto_eval_events, {
      group = group,
      callback = function(args)
        local bufnr = args.buf
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        if vim.bo[bufnr].buftype ~= "" then
          return
        end
        if vim.bo[bufnr].filetype == "solva-results" then
          return
        end
        if not should_auto_eval(bufnr) then
          return
        end

        local tick = vim.api.nvim_buf_get_changedtick(bufnr)
        debounce_state[bufnr] = tick
        vim.defer_fn(function()
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          if debounce_state[bufnr] ~= tick then
            return
          end
          require("solva").eval_buffer(bufnr)
        end, config.options.auto_eval_debounce_ms)
      end,
    })
  end
end

return M
