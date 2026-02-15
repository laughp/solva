local M = {}

local units = {
  -- length (base: m)
  m = { group = "length", factor = 1, symbol = "m" },
  meter = { group = "length", factor = 1, symbol = "m" },
  meters = { group = "length", factor = 1, symbol = "m" },
  km = { group = "length", factor = 1000, symbol = "km" },
  cm = { group = "length", factor = 0.01, symbol = "cm" },
  mm = { group = "length", factor = 0.001, symbol = "mm" },
  mi = { group = "length", factor = 1609.344, symbol = "mi" },
  yd = { group = "length", factor = 0.9144, symbol = "yd" },
  ft = { group = "length", factor = 0.3048, symbol = "ft" },
  inch = { group = "length", factor = 0.0254, symbol = "in" },
  inches = { group = "length", factor = 0.0254, symbol = "in" },
  ["in"] = { group = "length", factor = 0.0254, symbol = "in" },

  -- mass (base: g)
  g = { group = "mass", factor = 1, symbol = "g" },
  gram = { group = "mass", factor = 1, symbol = "g" },
  grams = { group = "mass", factor = 1, symbol = "g" },
  kg = { group = "mass", factor = 1000, symbol = "kg" },
  lb = { group = "mass", factor = 453.59237, symbol = "lb" },
  lbs = { group = "mass", factor = 453.59237, symbol = "lb" },
  oz = { group = "mass", factor = 28.349523125, symbol = "oz" },

  -- time (base: s)
  s = { group = "time", factor = 1, symbol = "s" },
  sec = { group = "time", factor = 1, symbol = "s" },
  second = { group = "time", factor = 1, symbol = "s" },
  seconds = { group = "time", factor = 1, symbol = "s" },
  min = { group = "time", factor = 60, symbol = "min" },
  mins = { group = "time", factor = 60, symbol = "min" },
  h = { group = "time", factor = 3600, symbol = "h" },
  hr = { group = "time", factor = 3600, symbol = "h" },
  hrs = { group = "time", factor = 3600, symbol = "h" },
  day = { group = "time", factor = 86400, symbol = "day" },
  days = { group = "time", factor = 86400, symbol = "day" },

  -- temperature (stored in kelvin internally)
  c = { group = "temp", symbol = "C" },
  f = { group = "temp", symbol = "F" },
  k = { group = "temp", symbol = "K" },
  celsius = { group = "temp", symbol = "C" },
  fahrenheit = { group = "temp", symbol = "F" },
  kelvin = { group = "temp", symbol = "K" },

  -- currencies (base: usd)
  usd = { group = "currency", factor = 1, symbol = "USD" },
  eur = { group = "currency", factor = 1.08, symbol = "EUR" },
  gbp = { group = "currency", factor = 1.27, symbol = "GBP" },
  jpy = { group = "currency", factor = 0.0068, symbol = "JPY" },
}

local default_symbol_for_group = {
  length = "m",
  mass = "g",
  time = "s",
  temp = "K",
  currency = "USD",
}

local function scalar(v)
  return { kind = "scalar", value = v }
end

local function quantity(base_value, group, preferred_unit)
  return {
    kind = "quantity",
    base_value = base_value,
    group = group,
    preferred_unit = preferred_unit,
  }
end

local function normalize_input(line)
  local s = line
  s = s:gsub("€(%d[%d%._,]*)", "%1 eur")
  s = s:gsub("£(%d[%d%._,]*)", "%1 gbp")
  s = s:gsub("¥(%d[%d%._,]*)", "%1 jpy")
  return s
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function to_kelvin(v, unit)
  if unit == "c" or unit == "celsius" then
    return v + 273.15
  elseif unit == "f" or unit == "fahrenheit" then
    return (v - 32) * (5 / 9) + 273.15
  end
  return v
end

local function from_kelvin(v, unit)
  if unit == "c" or unit == "celsius" then
    return v - 273.15
  elseif unit == "f" or unit == "fahrenheit" then
    return (v - 273.15) * (9 / 5) + 32
  end
  return v
end

local function make_quantity(v, unit_name)
  local u = units[unit_name]
  if not u then
    error("Unknown unit: " .. unit_name)
  end
  if u.group == "temp" then
    return quantity(to_kelvin(v, unit_name), "temp", unit_name)
  end
  return quantity(v * u.factor, u.group, unit_name)
end

local function is_scalar(v)
  return v.kind == "scalar"
end

local function copy_value(v)
  if is_scalar(v) then
    return scalar(v.value)
  end
  return quantity(v.base_value, v.group, v.preferred_unit)
end

local function compatible_values(a, b)
  if is_scalar(a) and is_scalar(b) then
    return true
  end
  if (not is_scalar(a)) and (not is_scalar(b)) and a.group == b.group then
    return true
  end
  return false
end

local function convert_value(v, target_unit)
  local u = units[target_unit]
  if not u then
    error("Unknown conversion target: " .. target_unit)
  end
  if is_scalar(v) then
    error("Cannot convert scalar to unit")
  end
  if v.group ~= u.group then
    error("Incompatible conversion to " .. target_unit)
  end
  local out = copy_value(v)
  out.preferred_unit = target_unit
  return out
end

local function number_to_string(v, precision)
  local fmt = "%." .. tostring(precision) .. "f"
  local s = string.format(fmt, v)
  s = s:gsub("(%..-)0+$", "%1")
  s = s:gsub("%.$", "")
  if s == "-0" then
    s = "0"
  end
  return s
end

local function get_display_value(v, preferred_unit)
  if is_scalar(v) then
    return v.value, nil
  end

  local unit_name = preferred_unit or v.preferred_unit or default_symbol_for_group[v.group]
  local u = units[unit_name]
  if not u then
    unit_name = default_symbol_for_group[v.group]
    u = units[unit_name]
  end
  if v.group == "temp" then
    return from_kelvin(v.base_value, unit_name), u.symbol
  end
  return v.base_value / u.factor, u.symbol
end

local function format_value(v, precision, preferred_unit)
  local n, unit_symbol = get_display_value(v, preferred_unit)
  if unit_symbol then
    return number_to_string(n, precision) .. " " .. unit_symbol
  end
  return number_to_string(n, precision)
end

local function as_same_group(a, b)
  if is_scalar(a) or is_scalar(b) then
    error("Operation requires matching unit types")
  end
  if a.group ~= b.group then
    error("Incompatible units: " .. a.group .. " vs " .. b.group)
  end
end

local function binary_op(op, a, b)
  if op == "+" then
    if is_scalar(a) and is_scalar(b) then
      return scalar(a.value + b.value)
    end
    as_same_group(a, b)
    return quantity(a.base_value + b.base_value, a.group, a.preferred_unit)
  elseif op == "-" then
    if is_scalar(a) and is_scalar(b) then
      return scalar(a.value - b.value)
    end
    as_same_group(a, b)
    return quantity(a.base_value - b.base_value, a.group, a.preferred_unit)
  elseif op == "*" then
    if is_scalar(a) and is_scalar(b) then
      return scalar(a.value * b.value)
    elseif is_scalar(a) and not is_scalar(b) then
      return quantity(a.value * b.base_value, b.group, b.preferred_unit)
    elseif not is_scalar(a) and is_scalar(b) then
      return quantity(a.base_value * b.value, a.group, a.preferred_unit)
    end
    error("Multiplication of two unit quantities is not supported")
  elseif op == "/" then
    if is_scalar(a) and is_scalar(b) then
      return scalar(a.value / b.value)
    elseif not is_scalar(a) and is_scalar(b) then
      return quantity(a.base_value / b.value, a.group, a.preferred_unit)
    elseif not is_scalar(a) and not is_scalar(b) then
      as_same_group(a, b)
      return scalar(a.base_value / b.base_value)
    end
    error("Division by a unit quantity is not supported")
  elseif op == "^" then
    if not is_scalar(a) or not is_scalar(b) then
      error("Exponentiation only supports scalar values")
    end
    return scalar(a.value ^ b.value)
  end
  error("Unknown operator: " .. op)
end

local function require_scalar_arg(name, args, expected)
  if #args ~= expected then
    error("Function " .. name .. " needs " .. expected .. " argument(s)")
  end
  local arg = args[1]
  if not is_scalar(arg) then
    error("Function " .. name .. " only supports scalar values")
  end
  return arg
end

local function gcd_pair(a, b)
  a = math.abs(a)
  b = math.abs(b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

local function call_function(name, args)
  local fn = string.lower(name)
  if fn == "sqrt" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.sqrt(arg.value))
  elseif fn == "abs" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.abs(arg.value))
  elseif fn == "floor" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.floor(arg.value))
  elseif fn == "ceil" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.ceil(arg.value))
  elseif fn == "round" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.floor(arg.value + 0.5))
  elseif fn == "log" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.log10 and math.log10(arg.value) or (math.log(arg.value) / math.log(10)))
  elseif fn == "ln" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.log(arg.value))
  elseif fn == "sin" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.sin(arg.value))
  elseif fn == "cos" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.cos(arg.value))
  elseif fn == "tan" then
    local arg = require_scalar_arg(name, args, 1)
    return scalar(math.tan(arg.value))
  elseif fn == "gcf" then
    if #args < 1 then
      error("Function " .. name .. " needs at least one argument")
    end
    local g = nil
    for i, arg in ipairs(args) do
      if not is_scalar(arg) then
        error("Function " .. name .. " only supports scalar values")
      end
      local v = arg.value
      if v % 1 ~= 0 then
        error("Function " .. name .. " requires integer values; argument " .. i .. " was " .. tostring(v))
      end
      if g == nil then
        g = math.abs(v)
      else
        g = gcd_pair(g, v)
      end
    end
    return scalar(g or 0)
  end
  error("Unknown function: " .. name)
end

local function tokenize(input, max_tokens)
  local tokens = {}
  local i = 1
  local n = #input
  local count = 0

  local function push_token(tok)
    count = count + 1
    if max_tokens and count > max_tokens then
      error("Token limit exceeded (" .. tostring(max_tokens) .. ")")
    end
    table.insert(tokens, tok)
  end

  local function scan_number_end(start_idx)
    local j = start_idx
    while j <= n do
      local c = input:sub(j, j)
      if c:match("[%d%._]") then
        j = j + 1
      elseif c == "," then
        local nextc = input:sub(j + 1, j + 1)
        if nextc ~= "" and nextc:match("%d") then
          j = j + 1
        else
          break
        end
      else
        break
      end
    end
    return j
  end

  while i <= n do
    local ch = input:sub(i, i)
    if ch:match("%s") then
      i = i + 1
    elseif ch == "$" then
      local j = i + 1
      if j <= n and input:sub(j, j):match("[%d%.]") then
        j = scan_number_end(j)
        local raw = input:sub(i + 1, j - 1):gsub("[,_]", "")
        local num = tonumber(raw)
        if not num then
          error("Invalid currency number: " .. raw)
        end
        push_token({ type = "NUMBER", value = num, text = raw })
        push_token({ type = "IDENT", value = "usd", text = "usd" })
        i = j
      elseif j <= n and input:sub(j, j):match("[%a_]") then
        j = j + 1
        while j <= n and input:sub(j, j):match("[%a_%d]") do
          j = j + 1
        end
        local name = string.lower(input:sub(i + 1, j - 1))
        push_token({ type = "VAR", value = name, text = "$" .. name })
        i = j
      else
        error("Invalid variable name near: " .. input:sub(i, math.min(i + 8, n)))
      end
    elseif ch:match("[%+%-%*%/%^%(%)%,%%]") then
      push_token({ type = ch, text = ch })
      i = i + 1
    elseif ch:match("[%d%.]") then
      local j = scan_number_end(i)
      local raw = input:sub(i, j - 1):gsub("[,_]", "")
      local num = tonumber(raw)
      if not num then
        error("Invalid number: " .. raw)
      end
      push_token({ type = "NUMBER", value = num, text = raw })
      i = j
    elseif ch:match("[%a_]") then
      local j = i
      while j <= n and input:sub(j, j):match("[%a_%d]") do
        j = j + 1
      end
      local word = input:sub(i, j - 1)
      local lw = string.lower(word)
      if lw == "plus" then
        push_token({ type = "+", text = word })
      elseif lw == "minus" then
        push_token({ type = "-", text = word })
      elseif lw == "times" then
        push_token({ type = "*", text = word })
      elseif lw == "over" then
        push_token({ type = "/", text = word })
      elseif lw == "of" then
        push_token({ type = "*", text = word })
      else
        push_token({ type = "IDENT", value = lw, text = word })
      end
      i = j
    else
      error("Unexpected character: " .. ch)
    end
  end
  push_token({ type = "EOF", text = "" })
  return tokens
end

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens, vars)
  return setmetatable({ tokens = tokens, pos = 1, vars = vars or {}, max_depth = 128, depth = 0 }, Parser)
end

function Parser:enter()
  self.depth = self.depth + 1
  if self.depth > (self.max_depth or 128) then
    error("Parse depth limit exceeded (" .. tostring(self.max_depth) .. ")")
  end
end

function Parser:leave()
  self.depth = self.depth - 1
  if self.depth < 0 then
    self.depth = 0
  end
end

function Parser:peek()
  return self.tokens[self.pos]
end

function Parser:next()
  local t = self.tokens[self.pos]
  self.pos = self.pos + 1
  return t
end

function Parser:match(t)
  if self:peek().type == t then
    self:next()
    return true
  end
  return false
end

function Parser:expect(t)
  local tok = self:next()
  if tok.type ~= t then
    error("Expected " .. t .. ", got " .. tok.type)
  end
  return tok
end

function Parser:parse_expression()
  self:enter()
  local out = self:parse_add_sub()
  self:leave()
  return out
end

function Parser:parse_add_sub()
  local left = self:parse_mul_div()
  while true do
    local t = self:peek().type
    if t == "+" or t == "-" then
      local op = self:next().type
      local right = self:parse_mul_div()
      left = binary_op(op, left, right)
    else
      break
    end
  end
  return left
end

local function next_starts_primary(tok)
  return tok.type == "NUMBER" or tok.type == "IDENT" or tok.type == "VAR" or tok.type == "("
end

function Parser:parse_mul_div()
  local left = self:parse_power()
  while true do
    local t = self:peek().type
    if t == "*" or t == "/" then
      local op = self:next().type
      local right = self:parse_power()
      left = binary_op(op, left, right)
    elseif next_starts_primary(self:peek()) then
      -- Implicit multiplication: 2(3+4), 10 km, 5x where x is variable.
      local right = self:parse_power()
      left = binary_op("*", left, right)
    else
      break
    end
  end
  return left
end

function Parser:parse_power()
  self:enter()
  local left = self:parse_unary()
  if self:match("^") then
    local right = self:parse_power()
    left = binary_op("^", left, right)
  end
  self:leave()
  return left
end

function Parser:parse_unary()
  if self:match("+") then
    return self:parse_unary()
  elseif self:match("-") then
    local v = self:parse_unary()
    if is_scalar(v) then
      return scalar(-v.value)
    end
    return quantity(-v.base_value, v.group, v.preferred_unit)
  end
  return self:parse_postfix()
end

function Parser:parse_postfix()
  local v = self:parse_primary()
  while self:match("%") do
    if not is_scalar(v) then
      error("Percent operator only supports scalar values")
    end
    v = scalar(v.value / 100)
  end
  return v
end

function Parser:parse_primary()
  local tok = self:peek()
  if tok.type == "NUMBER" then
    self:next()
    local value = scalar(tok.value)
    local nxt = self:peek()
    if nxt.type == "IDENT" and units[nxt.value] then
      self:next()
      value = make_quantity(tok.value, nxt.value)
    end
    return value
  elseif tok.type == "VAR" then
    self:next()
    local v = self.vars[tok.value]
    if not v then
      error("Unknown variable: $" .. tok.value)
    end
    return copy_value(v)
  elseif tok.type == "IDENT" then
    self:next()
    local name = tok.value
    if self:match("(") then
      local args = {}
      if not self:match(")") then
        table.insert(args, self:parse_expression())
        while self:match(",") do
          table.insert(args, self:parse_expression())
        end
        self:expect(")")
      end
      return call_function(name, args)
    end
    if name == "pi" then
      return scalar(math.pi)
    elseif name == "e" then
      return scalar(math.exp(1))
    end
    if units[name] then
      return make_quantity(1, name)
    end
    local v = self.vars[name]
    if not v then
      error("Unknown variable: " .. name)
    end
    return copy_value(v)
  elseif self:match("(") then
    local v = self:parse_expression()
    self:expect(")")
    return v
  end
  error("Unexpected token: " .. tok.type)
end

local function split_top_level_in(s)
  local depth = 0
  local lower = string.lower(s)
  local i = 1
  while i <= #lower do
    local ch = lower:sub(i, i)
    if ch == "(" then
      depth = depth + 1
    elseif ch == ")" and depth > 0 then
      depth = depth - 1
    elseif depth == 0 and lower:sub(i, i + 3) == " in " then
      return trim(s:sub(1, i - 1)), trim(s:sub(i + 4))
    end
    i = i + 1
  end
  return nil, nil
end

local function strip_comment(line)
  local s = line
  local hash = s:find("#", 1, true)
  local slashes = s:find("//", 1, true)
  local cut = nil
  if hash then
    cut = hash
  end
  if slashes and (not cut or slashes < cut) then
    cut = slashes
  end
  if cut then
    s = s:sub(1, cut - 1)
  end
  return trim(s)
end

local function evaluate_expression(expr, vars, opts)
  opts = opts or {}
  local tokens = tokenize(normalize_input(expr), opts.max_tokens or 2048)
  local parser = Parser.new(tokens, vars)
  parser.max_depth = opts.max_parse_depth or 128
  local value = parser:parse_expression()
  if parser:peek().type ~= "EOF" then
    error("Unexpected token near: " .. parser:peek().text)
  end
  return value
end

local function set_last_result(ctx, value)
  ctx.last = copy_value(value)
  ctx.vars.ans = copy_value(value)
  ctx.vars._ = copy_value(value)
end

local function set_line_reference(ctx, line_number, value)
  if not line_number or line_number < 1 then
    return
  end
  ctx.vars["line" .. tostring(line_number)] = copy_value(value)
end

local function update_running_total(ctx, value)
  if not ctx.running_total then
    ctx.running_total = copy_value(value)
    return
  end
  if compatible_values(ctx.running_total, value) then
    ctx.running_total = binary_op("+", ctx.running_total, value)
  else
    -- Start a new subtotal block when types are incompatible.
    ctx.running_total = copy_value(value)
  end
end

local function evaluate_total_line(stripped, ctx, precision)
  local _, target = split_top_level_in(stripped)
  local total = ctx.running_total
  if not total then
    error("No running total yet")
  end
  if target and target ~= "" then
    total = convert_value(total, string.lower(target))
    return total, format_value(total, precision, string.lower(target))
  end
  return total, format_value(total, precision)
end

local function extract_labeled_expression(stripped)
  local label, expr = stripped:match("^([%a_][%w_ ]-):%s*(.+)$")
  if label and expr then
    return trim(expr)
  end
  return stripped
end

local month_names = {
  january = 1,
  jan = 1,
  february = 2,
  feb = 2,
  march = 3,
  mar = 3,
  april = 4,
  apr = 4,
  may = 5,
  june = 6,
  jun = 6,
  july = 7,
  jul = 7,
  august = 8,
  aug = 8,
  september = 9,
  sep = 9,
  sept = 9,
  october = 10,
  oct = 10,
  november = 11,
  nov = 11,
  december = 12,
  dec = 12,
}

local function is_leap_year(y)
  if y % 400 == 0 then
    return true
  end
  if y % 100 == 0 then
    return false
  end
  return y % 4 == 0
end

local function days_in_month(y, m)
  local mdays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  if m == 2 and is_leap_year(y) then
    return 29
  end
  return mdays[m]
end

-- Civil date conversion helpers (timezone/DST independent).
-- Based on Howard Hinnant's civil date algorithms.
local function days_from_civil(y, m, d)
  local yy = y
  local mm = m
  yy = yy - ((mm <= 2) and 1 or 0)
  local era = math.floor((yy >= 0 and yy or (yy - 399)) / 400)
  local yoe = yy - era * 400
  local mp = mm + ((mm > 2) and -3 or 9)
  local doy = math.floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

local function civil_from_days(z)
  local zz = z + 719468
  local era = math.floor((zz >= 0 and zz or (zz - 146096)) / 146097)
  local doe = zz - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp + ((mp < 10) and 3 or -9)
  y = y + ((m <= 2) and 1 or 0)
  return { year = y, month = m, day = d }
end

local function parse_date_expr(s)
  local t = trim(s)
  local lower = string.lower(t)
  local now = os.date("*t")

  if lower == "today" then
    return { year = now.year, month = now.month, day = now.day }
  end

  local y, m, d = t:match("^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
  if y then
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if m >= 1 and m <= 12 and d >= 1 and d <= days_in_month(y, m) then
      return { year = y, month = m, day = d }
    end
    return nil
  end

  local month_word, day_num, year_num = t:match("^([%a]+)%s+(%d%d?)%s+(%d%d%d%d)$")
  if not month_word then
    month_word, day_num = t:match("^([%a]+)%s+(%d%d?)$")
  end
  if month_word and day_num then
    local month = month_names[string.lower(month_word)]
    local day = tonumber(day_num)
    local year = tonumber(year_num) or now.year
    if month and day and day >= 1 and day <= days_in_month(year, month) then
      return { year = year, month = month, day = day }
    end
  end

  return nil
end

local function format_date(d)
  return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

local function add_months(date, delta)
  local y = date.year
  local m = date.month + delta
  local d = date.day

  while m > 12 do
    m = m - 12
    y = y + 1
  end
  while m < 1 do
    m = m + 12
    y = y - 1
  end

  local max_day = days_in_month(y, m)
  if d > max_day then
    d = max_day
  end
  return { year = y, month = m, day = d }
end

local function add_days(date, delta_days)
  local day_num = days_from_civil(date.year, date.month, date.day)
  return civil_from_days(day_num + delta_days)
end

local function apply_duration(date, terms)
  local out = { year = date.year, month = date.month, day = date.day }
  for _, term in ipairs(terms) do
    if term.unit == "day" then
      out = add_days(out, term.value)
    elseif term.unit == "week" then
      out = add_days(out, term.value * 7)
    elseif term.unit == "month" then
      out = add_months(out, term.value)
    elseif term.unit == "year" then
      out = add_months(out, term.value * 12)
    end
  end
  return out
end

local function parse_duration_terms(s)
  local rest = trim(s)
  local terms = {}
  local consumed = ""

  while rest ~= "" do
    local sign, num, unit, tail = rest:match("^([%+%-]?)%s*(%d+)%s*([%a]+)%s*(.*)$")
    if not num then
      return nil
    end
    local value = tonumber(num)
    if sign == "-" then
      value = -value
    end

    local u = string.lower(unit)
    if u:match("^day") then
      u = "day"
    elseif u:match("^week") then
      u = "week"
    elseif u:match("^month") then
      u = "month"
    elseif u:match("^year") then
      u = "year"
    elseif u:match("^hour") or u == "hr" or u == "hrs" or u == "h" then
      u = "hour"
    elseif u:match("^minute") or u == "min" or u == "mins" then
      u = "minute"
    elseif u:match("^second") or u == "sec" or u == "secs" or u == "s" then
      u = "second"
    else
      return nil
    end
    table.insert(terms, { value = value, unit = u })
    consumed = consumed .. sign .. tostring(num) .. unit
    rest = trim(tail or "")
  end

  if #terms == 0 then
    return nil
  end
  return terms
end

local function parse_time_expr(s)
  local t = trim(string.lower(s))

  local h, m, ap = t:match("^(%d%d?):(%d%d)%s*([ap]m?)$")
  if h and m then
    h, m = tonumber(h), tonumber(m)
    if h < 1 or h > 12 or m < 0 or m > 59 then
      return nil
    end
    if ap:sub(1, 1) == "a" then
      if h == 12 then
        h = 0
      end
    else
      if h ~= 12 then
        h = h + 12
      end
    end
    return h * 60 + m
  end

  local h24, m24 = t:match("^(%d%d?):(%d%d)$")
  if h24 and m24 then
    h24, m24 = tonumber(h24), tonumber(m24)
    if h24 >= 0 and h24 <= 23 and m24 >= 0 and m24 <= 59 then
      return h24 * 60 + m24
    end
  end

  local h2, ap2 = t:match("^(%d%d?)%s*([ap]m?)$")
  if h2 and ap2 then
    h2 = tonumber(h2)
    if h2 < 1 or h2 > 12 then
      return nil
    end
    if ap2:sub(1, 1) == "a" then
      if h2 == 12 then
        h2 = 0
      end
    else
      if h2 ~= 12 then
        h2 = h2 + 12
      end
    end
    return h2 * 60
  end

  return nil
end

local function format_clock(total_minutes, day_offset)
  local min_in_day = ((total_minutes % 1440) + 1440) % 1440
  local h24 = math.floor(min_in_day / 60)
  local m = min_in_day % 60
  local ap = h24 >= 12 and "pm" or "am"
  local h12 = h24 % 12
  if h12 == 0 then
    h12 = 12
  end
  local base = string.format("%d:%02d %s", h12, m, ap)
  if day_offset == 1 then
    return base .. " (+1 day)"
  elseif day_offset > 1 then
    return base .. " (+" .. tostring(day_offset) .. " days)"
  elseif day_offset == -1 then
    return base .. " (-1 day)"
  elseif day_offset < -1 then
    return base .. " (" .. tostring(day_offset) .. " days)"
  end
  return base
end

local function duration_to_minutes(terms, allow_calendar)
  local total = 0
  for _, term in ipairs(terms) do
    if term.unit == "minute" then
      total = total + term.value
    elseif term.unit == "hour" then
      total = total + term.value * 60
    elseif term.unit == "second" then
      total = total + (term.value / 60)
    elseif term.unit == "day" then
      total = total + term.value * 1440
    elseif term.unit == "week" then
      total = total + term.value * 7 * 1440
    elseif allow_calendar then
      return nil
    else
      return nil
    end
  end
  return total
end

local function format_duration_minutes(minutes)
  local sign = ""
  if minutes < 0 then
    sign = "-"
    minutes = -minutes
  end
  local h = math.floor(minutes / 60)
  local m = minutes % 60
  if h == 0 then
    if m == 1 then
      return sign .. "1 minute"
    end
    return sign .. tostring(m) .. " minutes"
  end
  if m == 0 then
    if h == 1 then
      return sign .. "1 hour"
    end
    return sign .. tostring(h) .. " hours"
  end
  local htxt = h == 1 and "1 hour" or (tostring(h) .. " hours")
  local mtxt = m == 1 and "1 minute" or (tostring(m) .. " minutes")
  return sign .. htxt .. " " .. mtxt
end

local function evaluate_date_math(stripped)
  local lower = string.lower(stripped)

  local from_a, from_b = lower:match("^from%s+(.-)%s+to%s+(.+)$")
  if from_a and from_b then
    local original_a, original_b = stripped:match("^from%s+(.-)%s+to%s+(.+)$")
    local ta = parse_time_expr(original_a or from_a)
    local tb = parse_time_expr(original_b or from_b)
    if ta and tb then
      local diff = tb - ta
      return format_duration_minutes(diff)
    end

    local da = parse_date_expr(original_a or from_a)
    local db = parse_date_expr(original_b or from_b)
    if not da or not db then
      error("Could not parse one of the dates/times")
    end
    local diff_days = days_from_civil(db.year, db.month, db.day) - days_from_civil(da.year, da.month, da.day)
    local abs_days = math.abs(diff_days)
    if abs_days == 1 then
      return "1 day"
    end
    return tostring(abs_days) .. " days"
  end

  local left, op, rhs = stripped:match("^(.-)%s+([%+%-])%s+(.+)$")
  if left and rhs then
    local base_time = parse_time_expr(left)
    if base_time then
      local terms = parse_duration_terms((op or "") .. " " .. rhs)
      if not terms then
        error("Could not parse time duration")
      end
      local delta = duration_to_minutes(terms, false)
      if not delta then
        error("Unsupported duration unit for time math")
      end
      local total = base_time + delta
      local day_offset = math.floor(total / 1440)
      return format_clock(total, day_offset)
    end

    local base_date = parse_date_expr(left)
    if base_date then
      local terms = parse_duration_terms((op or "") .. " " .. rhs)
      if not terms then
        error("Could not parse date duration")
      end
      for _, term in ipairs(terms) do
        if term.unit == "hour" or term.unit == "minute" or term.unit == "second" then
          error("Time units are not supported in date math yet")
        end
      end
      local out = apply_duration(base_date, terms)
      return format_date(out)
    end
  end

  return nil
end

function M.evaluate_line(line, ctx, opts)
  opts = opts or {}
  local precision = opts.precision or 6
  local line_number = opts.line_number
  local stripped = strip_comment(line)
  if #stripped > (opts.max_line_length or 10000) then
    error("Line length exceeds limit (" .. tostring(opts.max_line_length or 10000) .. ")")
  end
  if stripped == "" then
    return nil
  end

  local lowered = string.lower(stripped)
  if lowered == "total" or lowered == "subtotal" or lowered:match("^total%s+in%s+") or lowered:match("^subtotal%s+in%s+") then
    local value, rendered = evaluate_total_line(lowered, ctx, precision)
    set_last_result(ctx, value)
    set_line_reference(ctx, line_number, value)
    return rendered
  end

  local date_rendered = evaluate_date_math(stripped)
  if date_rendered then
    return date_rendered
  end

  stripped = extract_labeled_expression(stripped)

  date_rendered = evaluate_date_math(stripped)
  if date_rendered then
    return date_rendered
  end

  local var_name, rhs = stripped:match("^%$([%a_][%w_]*)%s*=%s*(.+)$")
  if var_name then
    local value = evaluate_expression(rhs, ctx.vars, opts)
    ctx.vars[string.lower(var_name)] = copy_value(value)
    set_last_result(ctx, value)
    set_line_reference(ctx, line_number, value)
    return format_value(value, precision)
  end

  local left, target = split_top_level_in(stripped)
  local value = evaluate_expression(left or stripped, ctx.vars, opts)
  if target and target ~= "" then
    value = convert_value(value, string.lower(target))
    local rendered = format_value(value, precision, string.lower(target))
    set_last_result(ctx, value)
    set_line_reference(ctx, line_number, value)
    update_running_total(ctx, value)
    return rendered
  end
  local rendered = format_value(value, precision)
  set_last_result(ctx, value)
  set_line_reference(ctx, line_number, value)
  update_running_total(ctx, value)
  return rendered
end

function M.new_context()
  return { vars = {}, last = nil, running_total = nil }
end

return M
