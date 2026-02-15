require("luacov.runner")

local run = require("tests.run")
local total, failed = run.run_all()

require("luacov").save_stats()
os.execute("luacov")

if failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("quit")
end
