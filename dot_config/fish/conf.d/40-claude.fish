# Keep Claude Code's configuration and data under the XDG config directory.
if not set -q CLAUDE_CONFIG_DIR; or test -z "$CLAUDE_CONFIG_DIR"
    if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        set -gx CLAUDE_CONFIG_DIR "$XDG_CONFIG_HOME/claude"
    else
        set -gx CLAUDE_CONFIG_DIR "$HOME/.config/claude"
    end
end
