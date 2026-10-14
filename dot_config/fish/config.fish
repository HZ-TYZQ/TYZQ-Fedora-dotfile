# ~/.config/fish/config.fish

# PATH: 与原 bash 配置一致，前置用户 bin 目录
for p in ~/.local/bin ~/bin
    if test -d $p; and not contains -- $p $PATH
        set -gx PATH $p $PATH
    end
end

# 默认编辑器：Neovim
set -gx EDITOR nvim
set -gx VISUAL nvim

# 仅在交互式 shell 中初始化终端 UI
# 保持自动化、脚本和 `fish -c` 调用无额外输出
if status is-interactive
    # fastfetch: 每个终端进程树只显示一次，嵌套 fish 继承标记不重复打印
    if not set -q FASTFETCH_SHOWN; and command -q fastfetch
        set -gx FASTFETCH_SHOWN 1
        fastfetch
    end

    # starship 提示符
    if command -q starship
        starship init fish | source
    end
end

function fish_user_key_bindings
    fish_vi_key_bindings
end
