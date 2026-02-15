local evaluator = require("solva.evaluator")

local function run_all()
  local total = 0
  local failed = 0

  local function pass()
    io.write(".")
  end

  local function fail(msg)
    failed = failed + 1
    io.write("\nFAIL: " .. msg .. "\n")
  end

  local function expect_equal(actual, expected, label)
    total = total + 1
    if actual == expected then
      pass()
      return
    end
    fail(string.format("%s\n  expected: %s\n  actual:   %s", label, tostring(expected), tostring(actual)))
  end

  local function expect_match(actual, pattern, label)
    total = total + 1
    if type(actual) == "string" and actual:match(pattern) then
      pass()
      return
    end
    fail(string.format("%s\n  expected pattern: %s\n  actual:           %s", label, pattern, tostring(actual)))
  end

  local function expect_error(fn, pattern, label)
    total = total + 1
    local ok, err = pcall(fn)
    if not ok and tostring(err):match(pattern) then
      pass()
      return
    end
    fail(string.format("%s\n  expected error pattern: %s\n  actual: %s / %s", label, pattern, tostring(ok), tostring(err)))
  end

  local function eval_line(ctx, line, line_number, precision)
    local opts
    if type(precision) == "table" then
      opts = vim.tbl_extend("force", { line_number = line_number, precision = 6 }, precision)
    else
      opts = { line_number = line_number, precision = precision or 6 }
    end
    return evaluator.evaluate_line(line, ctx, opts)
  end

  local function test_basic_math()
    local ctx = evaluator.new_context()
    expect_equal(eval_line(ctx, "2 + 3 * 4", 1), "14", "basic precedence")
    expect_equal(eval_line(ctx, "(2 + 3) * 4", 2), "20", "parentheses")
    expect_equal(eval_line(ctx, "200 + 10%", 3), "200.1", "percent postfix behavior")
    expect_equal(eval_line(ctx, "2 plus 3 times 4", 4), "14", "word operators")
    expect_equal(eval_line(ctx, "8 over 4", 5), "2", "word division")
    expect_equal(eval_line(ctx, "2(3+4)", 6), "14", "implicit multiplication with parens")
    expect_equal(eval_line(ctx, "2 of 5", 7), "10", "of keyword multiplication")
    expect_equal(eval_line(ctx, "pi", 8, 4), "3.1416", "pi constant")
    expect_equal(eval_line(ctx, "e", 9, 4), "2.7183", "e constant")
  end

  local function test_variables_and_lines()
    local ctx = evaluator.new_context()
    expect_equal(eval_line(ctx, "$rent = 2400", 1), "2400", "variable assignment")
    expect_equal(eval_line(ctx, "$rent * 12", 2), "28800", "variable usage")
    expect_equal(eval_line(ctx, "line1 + line2", 3), "31200", "line references")
    expect_equal(eval_line(ctx, "ans / 3", 4), "10400", "ans reference")
    expect_equal(eval_line(ctx, "$foo_1 = 7", 5), "7", "underscore variable")
    expect_equal(eval_line(ctx, "$foo_1 + line5", 6), "14", "var and line ref together")
  end

  local function test_functions_and_units()
    local ctx = evaluator.new_context()
    expect_equal(eval_line(ctx, "gcf(84, 126, 210)", 1), "42", "gcf variadic")
    expect_error(function()
      eval_line(ctx, "gcf(10, 2.5)", 2)
    end, "requires integer values", "gcf integer validation")
    expect_error(function()
      eval_line(ctx, "gcf()", 2)
    end, "needs at least one argument", "gcf arity validation")
    expect_equal(eval_line(ctx, "10 km in mi", 3, 4), "6.2137 mi", "unit conversion")
    expect_equal(eval_line(ctx, "72 f in c", 4, 2), "22.22 C", "temperature conversion")
    expect_equal(eval_line(ctx, "$100 + €50", 5), "154 USD", "currency symbols")
    expect_equal(eval_line(ctx, "£10 + ¥1000", 6, 4), "15.3543 GBP", "gbp/jpy symbol normalization")
    expect_equal(eval_line(ctx, "sqrt(81)", 7), "9", "sqrt")
    expect_equal(eval_line(ctx, "floor(2.9)", 8), "2", "floor")
    expect_equal(eval_line(ctx, "ceil(2.1)", 9), "3", "ceil")
    expect_equal(eval_line(ctx, "round(2.6)", 10), "3", "round")
    expect_equal(eval_line(ctx, "abs(-5)", 11), "5", "abs")
    expect_equal(eval_line(ctx, "log(100)", 12), "2", "log10")
    expect_equal(eval_line(ctx, "ln(e)", 13, 4), "1", "natural log")
    expect_equal(eval_line(ctx, "sin(0)", 14), "0", "sin")
    expect_equal(eval_line(ctx, "cos(0)", 15), "1", "cos")
    expect_equal(eval_line(ctx, "tan(0)", 16), "0", "tan")
    expect_equal(eval_line(ctx, "$1,200 + 300 usd", 17), "1500 USD", "currency with comma")
    expect_equal(eval_line(ctx, "0 c in f", 18, 2), "32 F", "celsius to fahrenheit")
  end

  local function test_totals_and_labels()
    local ctx = evaluator.new_context()
    expect_equal(eval_line(ctx, "Lunch: 14.5 usd", 1, 2), "14.5 USD", "label parsing")
    expect_equal(eval_line(ctx, "Coffee: 4.25 usd", 2, 2), "4.25 USD", "second labeled value")
    expect_equal(eval_line(ctx, "total", 3, 2), "18.75 USD", "running total")
    expect_equal(eval_line(ctx, "total in eur", 4, 2), "17.36 EUR", "total conversion")
    expect_equal(eval_line(ctx, "subtotal", 5, 2), "18.75 USD", "subtotal alias")

    local ctx2 = evaluator.new_context()
    expect_equal(eval_line(ctx2, "10 usd", 1), "10 USD", "seed total")
    expect_equal(eval_line(ctx2, "2 m", 2), "2 m", "incompatible value resets subtotal block")
    expect_equal(eval_line(ctx2, "total", 3), "2 m", "total after incompatible reset")
  end

  local function test_dates_and_times()
    local ctx = evaluator.new_context()
    expect_equal(eval_line(ctx, "2026-03-01 + 45 days", 1), "2026-04-15", "date plus duration")
    expect_equal(eval_line(ctx, "2026-03-01 - 2 weeks", 2), "2026-02-15", "date minus duration")
    expect_equal(eval_line(ctx, "from 2026-03-01 to 2026-03-15", 3), "14 days", "date range")
    expect_equal(eval_line(ctx, "3:35 am + 9 hours 20 minutes", 4), "12:55 pm", "time plus duration")
    expect_equal(eval_line(ctx, "14:10 + 45 min", 5), "2:55 pm", "24h time plus duration")
    expect_equal(eval_line(ctx, "from 9:15 am to 5:40 pm", 6), "8 hours 25 minutes", "time range")
    expect_equal(eval_line(ctx, "11:50 pm + 20 min", 7), "12:10 am (+1 day)", "time crossing midnight")
    expect_equal(eval_line(ctx, "from 5:40 pm to 9:15 am", 8), "-8 hours 25 minutes", "negative time range")
    expect_equal(eval_line(ctx, "12:05 am - 30 min", 9), "11:35 pm (-1 day)", "time negative day offset")
    expect_equal(eval_line(ctx, "March 12 2024 + 1 year", 9), "2025-03-12", "month-name date with year")
    expect_equal(eval_line(ctx, "2024-02-29 + 1 year", 10), "2025-02-28", "leap-year clamp")
    expect_equal(eval_line(ctx, "2026-03-01 + 2 months", 11), "2026-05-01", "month duration")
    expect_equal(eval_line(ctx, "2026-03-01 - 1 year", 12), "2025-03-01", "year duration")
    expect_equal(eval_line(ctx, "12 am + 1 hour", 13), "1:00 am", "12am handling")
    expect_equal(eval_line(ctx, "12 pm + 1 hour", 14), "1:00 pm", "12pm handling")
    expect_equal(eval_line(ctx, "from July 30 to March 12", 15), "140 days", "month-name date range absolute days")
    expect_equal(eval_line(ctx, "from 10:00 to 10:01", 16), "1 minute", "time range minute singular")
    expect_equal(eval_line(ctx, "9 am + 1 hour", 17), "10:00 am", "hour am shorthand")
    expect_equal(eval_line(ctx, "11:00 pm + 49 hours", 18), "12:00 am (+3 days)", "time >1 day offset")
    expect_equal(eval_line(ctx, "1:00 am - 50 hours", 19), "11:00 pm (-3 days)", "time <-1 day offset")
    expect_equal(eval_line(ctx, "from 10:00 to 9:59", 20), "-1 minute", "negative minute singular")
    expect_equal(eval_line(ctx, "today + 1 week", 21), eval_line(ctx, "today + 7 days", 22), "week normalization")

    local today_out = eval_line(ctx, "today + 3 weeks 2 days", 23)
    expect_match(today_out, "^%d%d%d%d%-%d%d%-%d%d$", "today expression yields ISO date")
  end

  local function test_comments_and_blanks()
    local ctx = evaluator.new_context()
    expect_equal(eval_line(ctx, "2 + 2 // inline comment", 1), "4", "slash comment stripping")
    expect_equal(eval_line(ctx, "3 + 4 # hash comment", 2), "7", "hash comment stripping")
    expect_equal(eval_line(ctx, "   ", 3), nil, "blank line returns nil")
  end

  local function test_errors()
    local ctx = evaluator.new_context()
    expect_error(function()
      eval_line(ctx, "$missing + 1", 1)
    end, "Unknown variable", "unknown variable error")
    expect_error(function()
      eval_line(ctx, "from foo to bar", 2)
    end, "Could not parse one of the dates/times", "bad date/time range error")
    expect_error(function()
      eval_line(ctx, "total", 3)
    end, "No running total yet", "total without prior values")
    expect_error(function()
      eval_line(ctx, "1 usd in m", 4)
    end, "Incompatible conversion", "incompatible unit conversion")
    expect_error(function()
      eval_line(ctx, "notafunc(2)", 5)
    end, "Unknown function", "unknown function error")
    expect_error(function()
      eval_line(ctx, "2026-03-01 + 2 hours", 6)
    end, "Time units are not supported in date math yet", "date with time units error")
    expect_error(function()
      eval_line(ctx, "3:00 pm + 2 months", 7)
    end, "Unsupported duration unit for time math", "time with month units error")
    expect_error(function()
      eval_line(ctx, "$ = 10", 8)
    end, "Invalid variable name", "invalid variable token")
    expect_error(function()
      eval_line(ctx, "foo(2)", 9)
    end, "Unknown function", "unknown function generic")
    expect_error(function()
      eval_line(ctx, "sqrt()", 10)
    end, "needs 1 argument", "function arity error")
    expect_error(function()
      eval_line(ctx, "sqrt(2 m)", 11)
    end, "only supports scalar values", "function scalar-only error")
    expect_error(function()
      eval_line(ctx, "2 m * 3 ft", 12)
    end, "Multiplication of two unit quantities is not supported", "quantity*quantity error")
    expect_error(function()
      eval_line(ctx, "2 / 3 m", 13)
    end, "Division by a unit quantity is not supported", "scalar divided by quantity error")
    expect_error(function()
      eval_line(ctx, "(2 m) ^ 2", 14)
    end, "Exponentiation only supports scalar values", "quantity exponentiation error")
    expect_error(function()
      eval_line(ctx, "(2 m)%", 15)
    end, "Percent operator only supports scalar values", "percent on quantity error")
    expect_error(function()
      eval_line(ctx, "10 blarg", 16)
    end, "Unknown variable", "unknown bare identifier error")
    expect_error(function()
      eval_line(ctx, "2026-13-01 + 1 day", 17)
    end, "Operation requires matching unit types", "invalid date is rejected")
    expect_error(function()
      eval_line(ctx, "from 25:00 to 1:00", 18)
    end, "Could not parse one of the dates/times", "invalid time range error")
    expect_error(function()
      eval_line(ctx, "1 usd in bogus", 19)
    end, "Unknown conversion target", "unknown conversion target")
    expect_error(function()
      eval_line(ctx, "10 in m", 20)
    end, "Cannot convert scalar to unit", "scalar conversion error")
    expect_error(function()
      eval_line(ctx, "today + apples", 21)
    end, "Could not parse date duration", "invalid date duration")
    expect_error(function()
      eval_line(ctx, "3:00 pm + apples", 22)
    end, "Could not parse time duration", "invalid time duration")
    expect_error(function()
      eval_line(ctx, "1:00 pm + 30", 23)
    end, "Could not parse time duration", "missing time unit")
    expect_equal(eval_line(ctx, "from 10:00 to 10:00 am", 24), "0 minutes", "mixed time formats in range")
  end

  local function test_guardrails()
    local ctx = evaluator.new_context()
    expect_error(function()
      eval_line(ctx, string.rep("1", 128), 1, { max_line_length = 32 })
    end, "Line length exceeds limit", "line length limit")

    expect_error(function()
      eval_line(ctx, "1+1+1+1+1+1+1+1+1+1+1+1+1+1+1+1", 2, { max_tokens = 8 })
    end, "Token limit exceeded", "token limit")

    expect_error(function()
      eval_line(ctx, string.rep("(", 40) .. "1" .. string.rep(")", 40), 3, { max_parse_depth = 16 })
    end, "Parse depth limit exceeded", "parse depth limit")
  end

  local tests = {
    test_basic_math,
    test_variables_and_lines,
    test_functions_and_units,
    test_totals_and_labels,
    test_dates_and_times,
    test_comments_and_blanks,
    test_errors,
    test_guardrails,
  }

  for _, fn in ipairs(tests) do
    fn()
  end

  io.write(string.format("\n\n%d tests, %d failures\n", total, failed))
  return total, failed
end

if ... == nil then
  local _, failed = run_all()
  if failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("quit")
  end
else
  return { run_all = run_all }
end
