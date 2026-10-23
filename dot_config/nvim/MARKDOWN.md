# Markdown 使用说明

重启 Neovim 后生效。`<leader>` 是空格，以下快捷键仅在 Markdown 缓冲区可用。

| 快捷键 | 功能 |
| --- | --- |
| `空格 m p` | 打开或关闭浏览器预览，与原来的 `空格 c p` 相同 |
| `空格 m r` | 切换当前缓冲区的 Markdown 渲染 |
| `空格 m f` | 格式化当前文档，与原来的 `空格 c f` 相同 |
| `空格 m o` | 搜索标题大纲，回车跳转，需要 Marksman 完成启动 |
| `空格 m x` | 切换任务完成状态，或把普通列表项转换为任务项 |
| `空格 u m` | 原有的 Markdown 全局渲染开关 |
| `gx` | 原有的打开光标下链接功能 |

## 显示与写作

普通模式显示标题层级、代码块、表格和任务框；插入或选择文本时显示源码。
光标所在行会临时显示源码，方便编辑标记。

长段落在屏幕上自动折行，输入时不强制插入换行符。无序列表和引用可用回车延续；空列表项按一次退格去掉标记。
拼写检查和 markdownlint 继续关闭。

Prettier 由 Mason 管理。沿用 LazyVim 的保存格式化机制，项目内的 Prettier 配置仍然生效。
可以用 `空格 u F` 切换当前缓冲区的保存格式化，`空格 u f` 切换全局保存格式化。
需要自动目录时，在正文中放入 `<!-- toc -->`，然后格式化；原有的 markdown-toc 会更新目录。

## 浏览器预览

手动打开预览后，多个 Markdown 文件共用一个预览页。切换文件会更新预览内容，切到代码缓冲区时预览保持打开。
可以用 `:MarkdownPreviewStop` 停止预览。

## 试用区域

- [ ] 把光标移到这里，按 `空格 m x`
- [x] 已完成的任务，再按一次可以取消
- 普通列表项按 `空格 m x` 会变成待办项

```lua
print("Markdown 代码块")
```

| 项目 | 状态 |
| --- | --- |
| 中文显示 | 自动折行 |
| 表格排版 | Prettier 格式化 |

## 配置位置

- `lua/plugins/markdown.lua`：渲染、预览、格式化和诊断设置。
- `after/ftplugin/markdown.lua`：Markdown 局部选项和快捷键。
- 原配置备份：`~/.local/state/nvim/config-backups/markdown-20261011/`。

基础插件由 [LazyVim Markdown extra](https://www.lazyvim.org/extras/lang/markdown) 提供。
