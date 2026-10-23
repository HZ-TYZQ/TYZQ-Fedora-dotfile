#!/bin/sh
# Claude Code status line - minimal.
#   Opus 5[high]  ctx 34%  5h 12% ↻2h14m  7d 74% ↻3d4h  ~/dev/foo main*⇡2
#
# Segment order: model[effort]  context  5h quota  7d quota  dir + git
# POSIX sh (login shell is fish). jq parses the stdin JSON; without it only the
# model and directory segments are shown.

input=$(cat)

cwd=""; model=""; effort=""; ctx=""; h5=""; h5r=""; d7=""; d7r=""
if command -v jq >/dev/null 2>&1; then
  eval "$(printf '%s' "$input" | jq -r '
      @sh "cwd=\(.workspace.current_dir // .cwd // "")",
      @sh "model=\(.model.display_name // "")",
      @sh "effort=\(.effort.level // "")",
      @sh "ctx=\(.context_window.used_percentage // "")",
      @sh "h5=\(.rate_limits.five_hour.used_percentage // "")",
      @sh "h5r=\(.rate_limits.five_hour.resets_at // "")",
      @sh "d7=\(.rate_limits.seven_day.used_percentage // "")",
      @sh "d7r=\(.rate_limits.seven_day.resets_at // "")"')"
else
  cwd=$(printf '%s' "$input" | grep -o '"current_dir"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
  model=$(printf '%s' "$input" | grep -o '"display_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
fi
[ -n "$cwd" ] || cwd="$PWD"
[ -n "$model" ] || model="Claude"

esc=$(printf '\033')
r="${esc}[0m"
fg() { printf '%s[38;2;%s;%s;%sm' "$esc" "$1" "$2" "$3"; }

c_model=$(fg 197 168 189)  # mauve
c_dim=$(fg 126 140 153)    # dim slate - effort, low gauges
c_warn=$(fg 217 160 91)    # amber
c_crit=$(fg 217 108 108)   # red
c_dir=$(fg 143 184 207)    # muted blue
c_git=$(fg 180 159 201)    # muted lavender
c_dirty=$(fg 201 169 140)  # muted amber

# ---- 1. model name + reasoning effort ------------------------------------
line="${c_model}${model}${r}"
if [ -n "$effort" ]; then
  case "$effort" in medium) eff=med ;; *) eff=$effort ;; esac
  line="${line}${c_dim}[${eff}]${r}"
fi

# ---- 2-4. gauges: context window, then the two quota windows -------------
eta() {  # $1 = resets_at epoch seconds -> compact "3d4h" / "2h14m" / "47m"
  [ -n "$1" ] || return 0
  now=$(date +%s)
  left=$(awk -v t="$1" -v n="$now" 'BEGIN{printf "%d", t-n}' 2>/dev/null) || return 0
  [ "${left:-0}" -gt 0 ] || return 0
  d=$((left / 86400)); h=$((left % 86400 / 3600)); m=$((left % 3600 / 60))
  if   [ "$d" -gt 0 ] && [ "$h" -gt 0 ]; then printf ' ↻%dd%dh' "$d" "$h"
  elif [ "$d" -gt 0 ];                   then printf ' ↻%dd' "$d"
  elif [ "$h" -gt 0 ] && [ "$m" -gt 0 ]; then printf ' ↻%dh%dm' "$h" "$m"
  elif [ "$h" -gt 0 ];                   then printf ' ↻%dh' "$h"
  else                                        printf ' ↻%dm' "$m"
  fi
}

gauge() {  # $1 = label, $2 = used_percentage, $3 = resets_at (optional)
  [ -n "$2" ] || return 0
  pct=$(awk -v v="$2" 'BEGIN{printf "%.0f", v}' 2>/dev/null) || return 0
  case 1 in
    $((pct >= 85))) col=$c_crit ;;
    $((pct >= 60))) col=$c_warn ;;
    *)              col=$c_dim ;;
  esac
  printf '  %s%s %s%%%b%s' "$col" "$1" "$pct" "$(eta "$3")" "$r"
}
line="${line}$(gauge ctx "$ctx")$(gauge 5h "$h5" "$h5r")$(gauge 7d "$d7" "$d7r")"

# ---- 5. working directory (~ for $HOME, last two components) -------------
case "$cwd" in
  "$HOME")   dir="~" ;;
  "$HOME"/*) dir="~/${cwd#"$HOME"/}" ;;
  *)         dir="$cwd" ;;
esac
oldifs=$IFS; IFS=/; set -- $dir; IFS=$oldifs
if [ $# -gt 2 ]; then shift $(($# - 2)); dir="…/$1/$2"; fi
line="${line}  ${c_dir}${dir}${r}"

# ---- git rides along with the directory ---------------------------------
if command -v git >/dev/null 2>&1 && git --no-optional-locks -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
  [ -n "$branch" ] || branch=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    marks=""
    [ -n "$(git --no-optional-locks -C "$cwd" status --porcelain=v1 2>/dev/null)" ] && marks="*"
    ab=$(git --no-optional-locks -C "$cwd" rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null)
    if [ -n "$ab" ]; then
      ahead=$(printf '%s' "$ab" | awk '{print $1+0}')
      behind=$(printf '%s' "$ab" | awk '{print $2+0}')
      [ "$ahead" -gt 0 ] && marks="${marks}⇡${ahead}"
      [ "$behind" -gt 0 ] && marks="${marks}⇣${behind}"
    fi
    line="${line} ${c_git}${branch}${r}${c_dirty}${marks}${r}"
  fi
fi

printf '%s\n' "$line"
