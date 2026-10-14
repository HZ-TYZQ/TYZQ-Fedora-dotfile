-- 只作用于 Markdown；保留手动分行，中文长段落用屏幕折行显示。
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.spell = false
vim.opt_local.textwidth = 0
vim.opt_local.formatoptions:remove({ "t", "c" })
vim.opt_local.formatoptions:append("r") -- 回车延续无序列表和引用

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = true, silent = true, desc = desc })
end

map("<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", "Markdown Preview")
map("<leader>mr", function()
  require("render-markdown").buf_toggle()
end, "Markdown Render (Buffer)")
map("<leader>mf", function()
  LazyVim.format({ force = true })
end, "Markdown Format")
map("<leader>mo", function()
  Snacks.picker.lsp_symbols({ filter = { markdown = true } })
end, "Markdown Outline")
map("<leader>mx", function()
  local line = vim.api.nvim_get_current_line()
  local prefix, text = line:match("^(%s*[-+*]%s+)(.*)$")
  if not prefix then
    prefix, text = line:match("^(%s*%d+[.)]%s+)(.*)$")
  end
  if not prefix then
    vim.notify("请将光标放在列表或任务项上", vim.log.levels.INFO)
    return
  end

  -- 防止把代码块里的列表示例改成任务项。
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  vim.treesitter.get_parser(0, "markdown"):parse()
  local node = vim.treesitter.get_node({ pos = { row, #prefix - 1 }, ignore_injections = true })
  while node do
    if node:type() == "fenced_code_block" or node:type() == "indented_code_block" then
      return
    end
    node = node:parent()
  end

  if text:match("^%[[ xX]%]%s") or text:match("^%[[ xX]%]$") then
    text = (text:sub(2, 2) == " " and "[x]" or "[ ]") .. text:sub(4)
  else
    text = "[ ] " .. text
  end
  vim.api.nvim_set_current_line(prefix .. text)
end, "Markdown Toggle Task")

-- 切换文件类型时撤销本文件设置及快捷键。
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "")
  .. "|setlocal wrap< linebreak< breakindent< spell< textwidth< formatoptions<"
for _, key in ipairs({ "mp", "mr", "mf", "mo", "mx" }) do
  vim.b.undo_ftplugin = vim.b.undo_ftplugin .. "|silent! nunmap <buffer> <leader>" .. key
end
