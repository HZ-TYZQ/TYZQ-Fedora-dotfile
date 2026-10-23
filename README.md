# TYZQ 的 dotfiles 配置

默认分支 `cachyos` 管理从 Fedora 迁移后、已在 CachyOS 上恢复并使用的配置。
`fedora` 由原 `master` 重命名而来，保留现有历史，包括已合并的 CachyOS 配置。
旧 Fedora 配置可在迁移前的 Git 历史中查看。
唯一维护源目录：`~/.local/share/chezmoi`。

## 已纳入管理

- Niri：窗口、快捷键、输入、会话和显示器配置；具体显示器方案由本机 chezmoi 设置选择。
- Noctalia：基础配置及 GUI 保存的面板、组件、主题、壁纸路径、闲置行为。
- Fcitx5：输入法、快捷键、拼音偏好、`bed-money` / `OriDark` 主题。
- Fish、Starship、Fastfetch：终端初始化、提示符、欢迎语和字符画。
- Kitty、Alacritty：字体、配色与默认终端选择。
- Qt6ct：Fusion 风格、Noto 字体、Papirus-Dark 图标及启动环境；配色由 Noctalia 生成，路径随家目录渲染。
- 桌面应用图标：Noctalia、GTK 3/4 和 Qt6ct 统一使用 Papirus-Dark。
- mpv：Mochi 控制栏、快捷键、字幕、播放偏好和自动省电脚本。
- Zsh、Vim：启动配置及缓存、状态文件的位置设置。
- Neovim：LazyVim 配置、插件锁定文件、Markdown 配置及 Taplo 兼容设置。
- 英文 XDG 用户目录设置、`qq-show` 启动脚本。

没有安装脚本或自动提交、推送、应用钩子。软件、字体、壁纸和插件运行数据另外恢复。
浏览器登录、密钥、keyring、gh 凭证、输入法用户词库、历史和缓存不纳入本仓库。
Git 全局配置和 npm 的个人配置只在本机保留，其 chezmoi 源副本由 `.gitignore` 排除。
`private_dot_local/` 也只在本机保留，其中的 Noctalia GUI 设置、Fcitx5 主题和
`qq-show` 脚本需要在新机器另行恢复。
Noctalia 生成的颜色文件不纳管；天气位置从本机已有设置读取，不写进 Git。

## 日常保存

在家目录或应用界面修改配置后：

```sh
chezmoi re-add
python3 ~/.local/share/chezmoi/scripts/capture-noctalia.py
chezmoi diff
chezmoi git status --short
chezmoi git diff
```

`re-add` 更新已管理的普通文件；新文件需要单独 `chezmoi add 路径`。
Noctalia 的 GUI 设置用上面的脚本保存，它会移除天气位置数值并模板化家目录路径。
Niri 的入口是模板，用 `chezmoi edit ~/.config/niri/config.kdl` 修改；其他 Niri 片段可正常 `re-add`。
Qt6ct 也使用模板，用 `chezmoi edit ~/.config/qt6ct/qt6ct.conf` 修改；普通 `re-add` 会跳过模板。

确认 Git 差异后，按具体路径 `git add`，再提交和推送。不要直接添加整个家目录或 `.config`。
更多部署、依赖与维护说明见 [使用指南](docs/使用指南.md)。
