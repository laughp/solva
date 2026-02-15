if vim.g.loaded_solva_nvim == 1 then
  return
end
vim.g.loaded_solva_nvim = 1

vim.api.nvim_create_user_command("SolvaEvalLine", function()
  require("solva").eval_current_line()
end, {})

vim.api.nvim_create_user_command("SolvaEvalBuffer", function()
  require("solva").eval_buffer()
end, {})

vim.api.nvim_create_user_command("SolvaEval", function(cmd)
  require("solva").eval_range(cmd.line1, cmd.line2)
end, { range = true })

vim.api.nvim_create_user_command("SolvaClear", function()
  require("solva").clear()
end, {})

vim.api.nvim_create_user_command("SolvaOpenSplit", function()
  require("solva").open_split()
end, {})

vim.api.nvim_create_user_command("SolvaCloseSplit", function()
  require("solva").close_split()
end, {})

vim.api.nvim_create_user_command("SolvaEnable", function()
  require("solva").enable_buffer()
  require("solva").eval_buffer()
end, {})

vim.api.nvim_create_user_command("SolvaDisable", function()
  require("solva").disable_buffer()
  require("solva").close_split()
  require("solva").clear()
end, {})
