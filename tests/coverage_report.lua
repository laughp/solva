local target_path = "lua/solva/evaluator.lua"
local target_suffix = "lua/solva/evaluator.lua"

local executable = {}
local hits = {}
local lines = vim.fn.readfile(target_path)

local function build_skip_ranges()
  local ranges = {}
  local starts = {
    "^local%s+units%s*=%s*{%s*$",
    "^local%s+default_symbol_for_group%s*=%s*{%s*$",
    "^local%s+month_names%s*=%s*{%s*$",
  }

  for i, text in ipairs(lines) do
    local t = text:gsub("^%s+", ""):gsub("%s+$", "")
    for _, patt in ipairs(starts) do
      if t:match(patt) then
        local depth = 0
        for j = i, #lines do
          local row = lines[j]
          for _ in row:gmatch("{") do
            depth = depth + 1
          end
          for _ in row:gmatch("}") do
            depth = depth - 1
          end
          if depth == 0 then
            ranges[#ranges + 1] = { i, j }
            break
          end
        end
      end
    end
  end
  return ranges
end

local skip_ranges = build_skip_ranges()

local function in_skip_range(line_no)
  for _, r in ipairs(skip_ranges) do
    if line_no >= r[1] and line_no <= r[2] then
      return true
    end
  end
  return false
end

for line, text in ipairs(lines) do
  local t = text:gsub("^%s+", ""):gsub("%s+$", "")
  if
    t ~= ""
    and not t:match("^%-%-")
    and not in_skip_range(line)
    and not t:match("^local%s+M%s*=%s*{}$")
    and not t:match("^local%s+function%s+[%w_]+%s*%(")
    and not t:match("^function%s+[%w_%.:]+%s*%(")
    and not t:match("^end[,;]?$")
    and not t:match("^else$")
    and not t:match("^elseif%s")
    and not t:match("^return%s*{%s*$")
    and not t:match("^}%s*,?$")
  then
    executable[line] = true
  end
end

local function hook(_, line)
  local info = debug.getinfo(2, "S")
  if info and info.source and info.source:match(target_suffix .. "$") then
    hits[line] = (hits[line] or 0) + 1
  end
end

debug.sethook(hook, "l")
package.loaded["solva.evaluator"] = nil
package.loaded["tests.run"] = nil
local run = require("tests.run")
local total_tests, failed = run.run_all()
debug.sethook()

local total_lines = 0
local covered_lines = 0
for line, _ in pairs(executable) do
  total_lines = total_lines + 1
  if hits[line] then
    covered_lines = covered_lines + 1
  end
end

local pct = 0
if total_lines > 0 then
  pct = (covered_lines / total_lines) * 100
end

local uncovered = {}
for line, _ in pairs(executable) do
  if not hits[line] then
    uncovered[#uncovered + 1] = line
  end
end
table.sort(uncovered)

print("")
print("Coverage report: lua/solva/evaluator.lua")
print(string.format("Covered %d / %d executable lines (%.2f%%)", covered_lines, total_lines, pct))
print(string.format("Skipped static/structural lines: %d", #lines - total_lines))

if #uncovered > 0 then
  local preview = {}
  for i = 1, math.min(#uncovered, 25) do
    preview[#preview + 1] = tostring(uncovered[i])
  end
  print("First uncovered lines: " .. table.concat(preview, ", "))
end

print(string.format("Tests run: %d, failures: %d", total_tests, failed))

if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("quit")
end
