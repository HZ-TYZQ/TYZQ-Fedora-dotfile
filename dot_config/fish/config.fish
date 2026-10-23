# Select Vi mode before CachyOS adds mode-specific key bindings.
set -g fish_key_bindings fish_vi_key_bindings

source /usr/share/cachyos-fish-config/cachyos-config.fish

# Terminal appearance restored from TYZQ-Fedora-dotfile.
if status is-interactive
    # Override CachyOS's fastfetch greeting with the original greeting.
    source ~/.config/fish/functions/fish_greeting.fish

    # Display fastfetch once per terminal process tree.
    if not set -q FASTFETCH_SHOWN; and command -q fastfetch
        set -gx FASTFETCH_SHOWN 1
        fastfetch
    end

    if command -q starship
        starship init fish | source
    end
end
