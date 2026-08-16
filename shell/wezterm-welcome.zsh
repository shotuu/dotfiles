# Welcome banner shown once per new WezTerm tab (not on splits or nested
# shells). wezterm.lua sets WEZTERM_NEW_TAB=1 when spawning a new tab via
# Cmd-T, LEADER c, or the gui-startup handler for the very first window; we
# consume and unset it immediately so a subshell opened inside that same
# pane never re-triggers it.
if [[ -z "$WEZTERM_NEW_TAB" ]]; then
  return 0 2>/dev/null || exit 0
fi
unset WEZTERM_NEW_TAB

# Rose Pine Moon palette, matching .config/wezterm/wezterm.lua's `rose`
# table. Color roles used throughout this file: iris is the accent (the
# greeting, directory bars, the tip label) so the eye has one consistent
# "this is emphasis" color; foam marks primary read-out values (hostname,
# OS); gold is the warm highlight (moon-adjacent stars, the quote mark);
# text is for body content that needs to stay legible; subtle/muted/
# highlight_med step down for labels, separators, and background texture.
typeset -A _wc_rose=(
  base          "#232136"
  surface       "#2a273f"
  muted         "#6e6a86"
  subtle        "#908caa"
  text          "#e0def4"
  love          "#eb6f92"
  gold          "#f6c177"
  pine          "#3e8fb0"
  foam          "#9ccfd8"
  iris          "#c4a7e7"
  highlight_med "#44415a"
)

# Visible width of the box interior (between the two border characters,
# excluding the 1-space pad on each side). Every content line is expected
# to fit within this after its own internal indent; the widest thing that
# has to (the Terrace-font rendering of "afternoon slump", the widest
# phrase in the greeting pool below) comes in at 152, so this leaves a bit
# of slack while still fitting inside a plain full-width WezTerm tab (~198
# columns here).
typeset -gi _WC_CONTENT_WIDTH=160

# Two-column layout (system info beside recent directories): each column's
# visible width, and the gap of plain space between them. col*2 + gap =
# _WC_CONTENT_WIDTH.
typeset -gi _WC_COL_WIDTH=77
typeset -gi _WC_GAP=6

_wc() {
  local hex=$_wc_rose[$1]
  local r=$((16#${hex:1:2})) g=$((16#${hex:3:2})) b=$((16#${hex:5:2}))
  local style=${3:+$3;}
  printf '\033[%s38;2;%d;%d;%dm%s\033[0m' "$style" "$r" "$g" "$b" "$2"
}

# A night-sky line: densely scattered star glyphs, mostly dim `subtle` with
# a scattering of brighter `text` and warm `gold` ones mixed in so it reads
# as varied and alive rather than a flat wash of one color. `moon_col`, when
# >0, places a moon emoji (a real double-width glyph reads as an actual
# moon at a glance, unlike hand-drawn block art) -- reserving the column
# after it too, since the emoji occupies two terminal cells. Fills exactly
# `width` visible columns and no more, so it can go straight into the box
# border with no extra padding needed.
_wc_starline() {
  local width=$1 moon_col=$2
  local -a glyphs=('.' '·' '+' '✦' '*' '˙')
  local -A star_at
  local n placed col i roll
  n=$(( (RANDOM % 6) + 18 ))
  placed=0
  while (( placed < n )); do
    col=$(( (RANDOM % (width - 4)) + 1 ))
    (( moon_col > 0 && ( col == moon_col || col == moon_col + 1 ) )) && continue
    [[ -n "${star_at[$col]}" ]] && continue
    star_at[$col]="${glyphs[$(( (RANDOM % ${#glyphs[@]}) + 1 ))]}"
    (( placed++ ))
  done
  for (( i = 1; i <= width; i++ )); do
    if (( i == moon_col )); then
      printf '🌙'
      (( i++ ))
    elif [[ -n "${star_at[$i]}" ]]; then
      roll=$(( RANDOM % 6 ))
      if (( roll == 0 )); then
        _wc gold "${star_at[$i]}"
      elif (( roll <= 2 )); then
        _wc text "${star_at[$i]}"
      else
        _wc subtle "${star_at[$i]}"
      fi
    else
      printf ' '
    fi
  done
  printf '\n'
}

# Strips this file's own SGR sequences and measures the *visible* column
# width of a line, correcting for the moon emoji (one codepoint, two
# terminal columns) -- needed to pad box rows to a consistent width even
# though the raw string already contains ANSI color codes and wide glyphs.
_wc_visible_width() {
  local stripped moons
  stripped=$(printf '%s' "$1" | sed -E $'s/\x1b\\[[0-9;]*m//g')
  moons=$(grep -o '🌙' <<<"$stripped" | wc -l | tr -d ' ')
  printf '%d' $(( ${#stripped} + moons ))
}

# Emits `width` visible columns of padding: mostly plain space with a
# scattering of dim/bright star glyphs. Shared by every blank stretch in
# the banner -- the outer box's right margin, the inter-column gutter, and
# the blank separator line between sub-sections -- so stars show up evenly
# everywhere there's empty space rather than pooling only in the dedicated
# starline rows (which is what happened when the box margin was the only
# place this logic ran).
_wc_star_pad() {
  local width=$1
  (( width <= 0 )) && return 0
  local -a glyphs=('.' '·' '+' '✦' '*' '˙')
  local -A star_at
  local num_stars=0
  if (( width >= 6 )); then
    num_stars=$(( width / 20 ))
    (( RANDOM % 100 < 40 )) && num_stars=$(( num_stars + 1 ))
    (( num_stars > 5 )) && num_stars=5
  fi
  local placed=0 pos tries=0
  while (( placed < num_stars && tries < 25 )); do
    pos=$(( (RANDOM % width) + 1 ))
    tries=$(( tries + 1 ))
    [[ -n "${star_at[$pos]}" ]] && continue
    star_at[$pos]="${glyphs[$(( (RANDOM % ${#glyphs[@]}) + 1 ))]}"
    (( placed++ ))
  done
  local pi roll
  for (( pi = 1; pi <= width; pi++ )); do
    if [[ -n "${star_at[$pi]}" ]]; then
      roll=$(( RANDOM % 3 ))
      if (( roll == 0 )); then
        _wc gold "${star_at[$pi]}"
      elif (( roll == 1 )); then
        _wc text "${star_at[$pi]}"
      else
        _wc subtle "${star_at[$pi]}"
      fi
    else
      printf ' '
    fi
  done
}

# Wraps one already-colored line in the box border, padding it out to
# _WC_CONTENT_WIDTH with _wc_star_pad.
_wc_box_line() {
  local raw=$1
  local visible pad_needed
  visible=$(_wc_visible_width "$raw")
  pad_needed=$(( _WC_CONTENT_WIDTH - visible ))
  (( pad_needed < 0 )) && pad_needed=0
  _wc muted "│"
  printf ' %s' "$raw"
  _wc_star_pad "$pad_needed"
  printf ' '
  _wc muted "│"
  printf '\n'
}

# Right-pads one already-colored line to `width` visible columns, via
# _wc_star_pad -- same texture as the outer box margin, so the inter-column
# gutter doesn't read as a dead strip next to it.
_wc_pad_to() {
  local raw=$1 width=$2 visible pad
  visible=$(_wc_visible_width "$raw")
  pad=$(( width - visible ))
  (( pad < 0 )) && pad=0
  printf '%s' "$raw"
  _wc_star_pad "$pad"
}

# Zips two multi-line (already-colored) blocks into side-by-side columns,
# one output line per row of the taller side -- the shorter side just pads
# out blank for its remaining rows.
_wc_two_column() {
  local raw_left=$1 raw_right=$2
  local -a left right
  left=("${(@f)raw_left}")
  right=("${(@f)raw_right}")
  local n=${#left[@]}
  (( ${#right[@]} > n )) && n=${#right[@]}
  local i
  for (( i = 1; i <= n; i++ )); do
    _wc_pad_to "${left[i]:-}" "$_WC_COL_WIDTH"
    _wc_star_pad "$_WC_GAP"
    printf '%s' "${right[i]:-}"
    printf '\n'
  done
}

# Fullwidth Unicode forms (U+FF00 block) render as double-width in a
# monospace terminal -- the fallback greeting style if figlet isn't
# installed. Only covers the letters the greeting phrases and ", daniel"
# ever use; anything else (spaces) passes through unchanged.
typeset -A _wc_fw=(
  a "ａ" b "ｂ" c "ｃ" d "ｄ" e "ｅ" f "ｆ" g "ｇ" h "ｈ" i "ｉ" j "ｊ"
  k "ｋ" l "ｌ" m "ｍ" n "ｎ" o "ｏ" p "ｐ" q "ｑ" r "ｒ" s "ｓ" t "ｔ"
  u "ｕ" v "ｖ" w "ｗ" x "ｘ" y "ｙ" z "ｚ" "," "，" "'" "＇"
)

_wc_fullwidth() {
  local word=$1 i ch out=""
  for (( i = 1; i <= ${#word}; i++ )); do
    ch="${word[$i]}"
    out+="${_wc_fw[$ch]:-$ch}"
  done
  printf '%s' "$out"
}

# "g o o d   e v e n i n g" -- regular-width letter-spacing for the small
# date subheading under the figlet greeting.
_wc_letterspace() {
  local word=$1 i out=""
  for (( i = 1; i <= ${#word}; i++ )); do
    out+="${word[$i]} "
  done
  printf '%s' "$out"
}

# Colors a multi-line block as a unit (one SGR code covering every line,
# rather than re-emitting it per line) -- used for the figlet greeting.
_wc_block() {
  local color=$1 text=$2 hex r g b line
  hex=$_wc_rose[$color]
  r=$((16#${hex:1:2})) g=$((16#${hex:3:2})) b=$((16#${hex:5:2}))
  while IFS= read -r line; do
    printf '\033[38;2;%d;%d;%dm  %s\033[0m\n' "$r" "$g" "$b" "$line"
  done <<<"$text"
}

# Bracketed block-bar, e.g. "[██████░░░░] 62%  discharging". Colored
# foam/gold/love for fine/warning/critical, matching the WezTerm status
# line and tab bar elsewhere in this repo.
_wc_bar() {
  local pct=$1 width=$2 label=$3
  local color filled empty bar i
  filled=$(( pct * width / 100 ))
  (( filled > width )) && filled=$width
  (( filled < 0 )) && filled=0
  empty=$(( width - filled ))
  bar=""
  for (( i = 0; i < filled; i++ )); do bar+="█"; done
  for (( i = 0; i < empty; i++ )); do bar+="░"; done
  if (( pct < 20 )); then
    color=love
  elif (( pct < 50 )); then
    color=gold
  else
    color=foam
  fi
  _wc $color "[$bar]"
  _wc text " ${pct}%"
  [[ -n "$label" ]] && _wc subtle "  ${label}"
}

# Icon + underlined label, used identically above every section so the
# banner reads as one consistent structure rather than differently-styled
# blocks stitched together. Headers get their own reserved color (gold,
# underlined) rather than reusing `iris` -- iris is already the general
# "accent" used all over the body (bars, the tip label), so a header in
# that same color wouldn't actually read as a distinct tier above it.
_wc_header() {
  printf '  '
  _wc gold "$1 "
  _wc gold "$2" "4"
  printf '\n'
}

_wc_os_version() {
  if command -v sw_vers >/dev/null 2>&1; then
    printf '%s %s' "$(sw_vers -productName)" "$(sw_vers -productVersion)"
  elif [[ -r /etc/os-release ]]; then
    awk -F= '/^PRETTY_NAME/{gsub("\"","",$2); print $2}' /etc/os-release
  else
    uname -sr
  fi
}

_wc_uptime() {
  local boot_epoch now_epoch secs d h m
  if command -v sysctl >/dev/null 2>&1 && boot_epoch=$(sysctl -n kern.boottime 2>/dev/null | sed -E 's/^\{ sec = ([0-9]+).*/\1/') && [[ "$boot_epoch" == <-> ]]; then
    now_epoch=$(date +%s)
    secs=$(( now_epoch - boot_epoch ))
  elif [[ -r /proc/uptime ]]; then
    secs=${$(</proc/uptime)%%.*}
  else
    return 1
  fi
  d=$(( secs / 86400 ))
  h=$(( secs % 86400 / 3600 ))
  m=$(( secs % 3600 / 60 ))
  printf '%dd %dh %dm' "$d" "$h" "$m"
}

_wc_loadavg() {
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk '{print $1, $2, $3}'
  elif [[ -r /proc/loadavg ]]; then
    awk '{print $1, $2, $3}' /proc/loadavg
  fi
}

# Prints "pct|used_gb|total_gb" on one line so the caller can split it,
# rather than returning multiple values directly (zsh functions only have
# one output stream to work with cleanly).
_wc_mem_stats() {
  local page_size pages_active pages_wired pages_compressed pages_used
  local total_bytes used_bytes pct used_gb total_gb
  if command -v vm_stat >/dev/null 2>&1; then
    page_size=$(vm_stat | head -1 | grep -oE '[0-9]+')
    pages_active=$(vm_stat | awk '/Pages active/{gsub("\\.","",$3); print $3}')
    pages_wired=$(vm_stat | awk '/Pages wired down/{gsub("\\.","",$4); print $4}')
    pages_compressed=$(vm_stat | awk '/occupied by compressor/{gsub("\\.","",$5); print $5}')
    pages_used=$(( pages_active + pages_wired + pages_compressed ))
    total_bytes=$(sysctl -n hw.memsize)
    used_bytes=$(( pages_used * page_size ))
  elif command -v free >/dev/null 2>&1; then
    used_bytes=$(free -b | awk 'NR==2{print $3}')
    total_bytes=$(free -b | awk 'NR==2{print $2}')
  else
    return 1
  fi
  (( total_bytes == 0 )) && return 1
  pct=$(( used_bytes * 100 / total_bytes ))
  used_gb=$(( used_bytes / 1073741824. ))
  total_gb=$(( total_bytes / 1073741824. ))
  printf '%d|%.1f|%.1f' "$pct" "$used_gb" "$total_gb"
}

# Claude Code caches its last-known usage utilization in ~/.claude.json
# (cachedUsageUtilization.utilization), refreshed whenever the CLI last
# talked to the backend -- there's no way for this script to force a fresh
# pull without spending an API call and needing credentials it doesn't
# have, so it just reports how old the cached reading is (via fetchedAtMs)
# alongside it, rather than implying it's live. This is undocumented/
# internal state, not a public API, so it's read defensively: any missing
# field, unexpected shape, or future schema change just means these rows
# don't show up rather than breaking the banner. Prints
# "five_pct|five_reset|week_pct|week_reset|age" where the *_pct values are
# *remaining* percentage (so _wc_bar's low-pct red styling means "running
# low," matching its use for battery).
_wc_claude_usage() {
  local config="$HOME/.claude.json"
  [[ -r "$config" ]] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$config" <<'PY' 2>/dev/null
import json, sys
from datetime import datetime, timezone

def fmt_reset(iso):
    if not iso:
        return ""
    try:
        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        local = dt.astimezone()
        if (dt - datetime.now(timezone.utc)).total_seconds() < 20 * 3600:
            return local.strftime("%-I:%M%p").lower()
        return local.strftime("%a").lower()
    except Exception:
        return ""

def fmt_age(fetched_ms):
    if not isinstance(fetched_ms, (int, float)):
        return ""
    age_s = datetime.now(timezone.utc).timestamp() - fetched_ms / 1000
    if age_s < 0:
        return ""
    if age_s < 60:
        return "just now"
    if age_s < 3600:
        return f"{int(age_s // 60)}m ago"
    if age_s < 86400:
        return f"{int(age_s // 3600)}h ago"
    return f"{int(age_s // 86400)}d ago"

try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    cached = data.get("cachedUsageUtilization") or {}
    util = cached.get("utilization") or {}
    five = util.get("five_hour") or {}
    week = util.get("seven_day") or {}
    five_pct = five.get("utilization")
    week_pct = week.get("utilization")
    if five_pct is None and week_pct is None:
        sys.exit(1)
    five_remaining = 100 - five_pct if isinstance(five_pct, (int, float)) else ""
    week_remaining = 100 - week_pct if isinstance(week_pct, (int, float)) else ""
    age = fmt_age(cached.get("fetchedAtMs"))
    print(f"{five_remaining}|{fmt_reset(five.get('resets_at'))}|{week_remaining}|{fmt_reset(week.get('resets_at'))}|{age}")
except Exception:
    sys.exit(1)
PY
}

# Codex writes the latest account rate-limit snapshot into its local session
# transcript whenever it completes a turn. This follows the same deliberately
# cached approach as the Claude section above: opening a tab never launches
# Codex or makes a network request. The transcript is internal state, so read
# it defensively and omit Codex when its format changes or no recent snapshot
# exists. Prints "primary_pct|primary_reset|primary_window|secondary_pct|
# secondary_reset|secondary_window|age", where pct is remaining percentage.
_wc_codex_usage() {
  local sessions_dir="$HOME/.codex/sessions"
  [[ -d "$sessions_dir" ]] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$sessions_dir" <<'PY' 2>/dev/null
import json, sys
from datetime import datetime, timezone
from pathlib import Path

def parse_time(value):
    if not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None

def fmt_reset(epoch):
    if not isinstance(epoch, (int, float)):
        return ""
    try:
        dt = datetime.fromtimestamp(epoch, tz=timezone.utc)
        local = dt.astimezone()
        if (dt - datetime.now(timezone.utc)).total_seconds() < 20 * 3600:
            return local.strftime("%-I:%M%p").lower()
        return local.strftime("%a").lower()
    except (OverflowError, OSError, ValueError):
        return ""

def fmt_window(minutes):
    if not isinstance(minutes, (int, float)) or minutes <= 0:
        return ""
    minutes = int(minutes)
    if minutes % 1440 == 0:
        return f"{minutes // 1440}d"
    if minutes % 60 == 0:
        return f"{minutes // 60}h"
    return f"{minutes}m"

def fmt_age(dt):
    if dt is None:
        return ""
    age_s = datetime.now(timezone.utc).timestamp() - dt.timestamp()
    if age_s < 0:
        return ""
    if age_s < 60:
        return "just now"
    if age_s < 3600:
        return f"{int(age_s // 60)}m ago"
    if age_s < 86400:
        return f"{int(age_s // 3600)}h ago"
    return f"{int(age_s // 86400)}d ago"

try:
    root = Path(sys.argv[1])
    # Only inspect the newest few transcripts. Each contains several rolling
    # snapshots, and choosing the newest timestamp among them avoids a large
    # history scan during shell startup.
    files = sorted(root.rglob("*.jsonl"), key=lambda path: path.stat().st_mtime, reverse=True)[:8]
    newest = None
    for path in files:
        try:
            with path.open() as stream:
                for line in stream:
                    record = json.loads(line)
                    payload = record.get("payload") or {}
                    limits = payload.get("rate_limits") or payload.get("rateLimits")
                    if not isinstance(limits, dict):
                        continue
                    timestamp = parse_time(record.get("timestamp"))
                    if timestamp is None:
                        continue
                    if newest is None or timestamp > newest[0]:
                        newest = (timestamp, limits)
        except (OSError, ValueError, json.JSONDecodeError):
            continue

    if newest is None:
        sys.exit(1)
    timestamp, limits = newest

    def read_window(name):
        window = limits.get(name) or {}
        used = window.get("used_percent", window.get("usedPercent"))
        if not isinstance(used, (int, float)):
            return ("", "", "")
        reset = window.get("resets_at", window.get("resetsAt"))
        duration = window.get("window_minutes", window.get("windowDurationMins"))
        return (str(max(0, min(100, round(100 - used)))), fmt_reset(reset), fmt_window(duration))

    primary = read_window("primary")
    secondary = read_window("secondary")
    if not primary[0] and not secondary[0]:
        sys.exit(1)
    print("|".join((*primary, *secondary, fmt_age(timestamp))))
except Exception:
    sys.exit(1)
PY
}

# One field per line (host/os/shell/uptime/load/memory/disk/battery) rather
# than combining os+shell+uptime+load onto one long line -- that combined
# line doesn't fit a two-column layout, and one-fact-per-row also happens to
# land at up to 8 rows, matching the recent-directories list it sits next
# to. `bar_width` is a parameter (rather than hardcoded) since it needs to
# shrink to fit a half-width column.
_wc_system_info() {
  local bar_width=${1:-18}
  local host os_name shell_info uptime_str load_str
  host=$(hostname -s 2>/dev/null)
  host=${(L)host}
  os_name=$(_wc_os_version)
  os_name=${(L)os_name}
  shell_info="zsh ${ZSH_VERSION:-?}"
  uptime_str=$(_wc_uptime)
  load_str=$(_wc_loadavg)

  printf '  '
  _wc subtle "$(printf '%-10s' 'host')"
  _wc foam "$host"
  printf '\n'

  printf '  '
  _wc subtle "$(printf '%-10s' 'os')"
  _wc foam "$os_name"
  printf '\n'

  printf '  '
  _wc subtle "$(printf '%-10s' 'shell')"
  _wc text "$shell_info"
  printf '\n'

  if [[ -n "$uptime_str" ]]; then
    printf '  '
    _wc subtle "$(printf '%-10s' 'uptime')"
    _wc text "$uptime_str"
    printf '\n'
  fi

  if [[ -n "$load_str" ]]; then
    printf '  '
    _wc subtle "$(printf '%-10s' 'load')"
    _wc text "$load_str"
    printf '\n'
  fi

  local mem_line mem_pct mem_used mem_total
  mem_line=$(_wc_mem_stats)
  if [[ -n "$mem_line" ]]; then
    IFS='|' read -r mem_pct mem_used mem_total <<<"$mem_line"
    printf '  '
    _wc subtle "$(printf '%-10s' 'memory')"
    _wc_bar "$mem_pct" "$bar_width" "${mem_used}/${mem_total}gb"
    printf '\n'
  fi

  local disk_pct_num
  disk_pct_num=$(df -H "$HOME" 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')
  if [[ -n "$disk_pct_num" ]]; then
    printf '  '
    _wc subtle "$(printf '%-10s' 'disk')"
    _wc_bar "$disk_pct_num" "$bar_width" "used"
    printf '\n'
  fi

  local battery_pct battery_state batt_line
  if command -v pmset >/dev/null 2>&1; then
    batt_line=$(pmset -g batt 2>/dev/null | grep -o 'InternalBattery.*')
    battery_pct=$(grep -Eo '[0-9]+%' <<<"$batt_line" | head -1 | tr -d '%')
    battery_state=$(grep -Eo 'charging|discharging|charged' <<<"$batt_line" | head -1)
  elif [[ -r /sys/class/power_supply/BAT0/capacity ]]; then
    battery_pct=$(cat /sys/class/power_supply/BAT0/capacity)
    [[ -r /sys/class/power_supply/BAT0/status ]] && battery_state=$(tr '[:upper:]' '[:lower:]' </sys/class/power_supply/BAT0/status)
  fi
  if [[ -n "$battery_pct" ]]; then
    printf '  '
    _wc subtle "$(printf '%-10s' 'battery')"
    _wc_bar "$battery_pct" "$bar_width" "$battery_state"
    printf '\n'
  fi
}

# Claude and Codex are both account/usage data rather than host data, so they
# share one section. The source name in each row makes the two agents easy to
# compare while keeping Codex directly beneath Claude.
_wc_agent_usage_section() {
  local bar_width=${1:-18}
  local claude_line five_pct five_reset week_pct week_reset claude_age
  local codex_line primary_pct primary_reset primary_window secondary_pct secondary_reset secondary_window codex_age
  claude_line=$(_wc_claude_usage)
  codex_line=$(_wc_codex_usage)
  [[ -n "$claude_line" || -n "$codex_line" ]] || return 0

  _wc_header "✳" "agent usage"
  if [[ -n "$claude_line" ]]; then
    IFS='|' read -r five_pct five_reset week_pct week_reset claude_age <<<"$claude_line"
    if [[ -n "$five_pct" ]]; then
      printf '  '
      _wc subtle "$(printf '%-10s' 'claude 5h')"
      _wc_bar "$five_pct" "$bar_width" "${five_reset:+resets $five_reset}"
      printf '\n'
    fi
    if [[ -n "$week_pct" ]]; then
      printf '  '
      _wc subtle "$(printf '%-10s' 'claude 7d')"
      _wc_bar "$week_pct" "$bar_width" "${week_reset:+resets $week_reset}"
      printf '\n'
    fi
    [[ -n "$claude_age" ]] && {
      printf '  '
      _wc muted "$(printf '%-10s' '')"
      _wc muted "claude updated ${claude_age}"
      printf '\n'
    }
  fi

  if [[ -n "$codex_line" ]]; then
    IFS='|' read -r primary_pct primary_reset primary_window secondary_pct secondary_reset secondary_window codex_age <<<"$codex_line"
    if [[ -n "$primary_pct" ]]; then
      printf '  '
      _wc subtle "$(printf '%-10s' "codex ${primary_window:-primary}")"
      _wc_bar "$primary_pct" "$bar_width" "${primary_reset:+resets $primary_reset}"
      printf '\n'
    fi
    if [[ -n "$secondary_pct" ]]; then
      printf '  '
      _wc subtle "$(printf '%-10s' "codex ${secondary_window:-secondary}")"
      _wc_bar "$secondary_pct" "$bar_width" "${secondary_reset:+resets $secondary_reset}"
      printf '\n'
    fi
    [[ -n "$codex_age" ]] && {
      printf '  '
      _wc muted "$(printf '%-10s' '')"
      _wc muted "codex updated ${codex_age}"
      printf '\n'
    }
  fi
}

# Most-recently-visited directories, deduplicated and numbered so they line
# up with the `j <n>` / `jj` jump commands defined in zshrc-managed-block.zsh
# (tracked via a chpwd hook into $RECENT_DIRS_FILE -- see that file for why
# this isn't sourced from zoxide). Bar length decays by rank rather than a
# real score, since a recency-ordered list has no score to chart, only an
# order. Only the numbered rows themselves -- capped at 8 to match
# _wc_system_info's row count for the two-column layout; the header and the
# jump hint are separate so the caller can place them independently (the
# header sits beside "· system", the hint runs full-width below both
# columns since it isn't tied to one row).
_wc_recent_dirs_rows() {
  local bar_width=${1:-20}
  [[ -n "$RECENT_DIRS_FILE" && -f "$RECENT_DIRS_FILE" ]] || return 0
  local -a rdirs rnames
  local rpath rname ri rj rbarlen rbar rname_width=0 rcount
  rdirs=("${(@f)$(<"$RECENT_DIRS_FILE")}")
  (( ${#rdirs[@]} == 0 )) && return 0
  (( ${#rdirs[@]} > 8 )) && rdirs=("${(@)rdirs[1,8]}")
  rcount=${#rdirs[@]}

  for rpath in "${rdirs[@]}"; do
    rname="${rpath:t}"
    rname=${(L)rname}
    (( ${#rname} > 21 )) && rname="${rname[1,20]}…"
    rnames+=("$rname")
    (( ${#rname} > rname_width )) && rname_width=${#rname}
  done

  for (( ri = 1; ri <= rcount; ri++ )); do
    rbarlen=$(( bar_width - (ri - 1) * bar_width / rcount ))
    (( rbarlen < 1 )) && rbarlen=1
    rbar=""
    for (( rj = 0; rj < rbarlen; rj++ )); do rbar+="█"; done
    for (( rj = rbarlen; rj < bar_width; rj++ )); do rbar+="░"; done
    printf '  '
    _wc iris "$(printf '%2d' "$ri")"
    printf '  '
    _wc text "$(printf '%-*s' "$rname_width" "${rnames[ri]}")"
    printf '  '
    _wc iris "$rbar"
    printf '\n'
  done
}

# Everything between the box borders, unwrapped -- _wc_box_line pads and
# frames each line of this afterward. Kept as its own function so its
# output can be captured as one string and split back into lines.
_wc_render_body() {
  local hour
  hour=$(date +%H)
  # A pool of possible greetings rather than one fixed phrase per time
  # bucket, so which one shows up is a small surprise each time a tab
  # opens. Some are anytime phrases (available regardless of the hour);
  # the rest are only added into the pool when they actually fit the
  # current time, so it won't wish you "good morning" at 11pm.
  local -a greeting_pool=(
    "hello again" "welcome back" "ready to build" "let's ship it" "systems online"
    "terminal ready" "here we go" "back at it" "hey there" "logged in"
    "all systems go" "code awaits"
  )
  if (( hour < 5 )); then
    greeting_pool+=("still up" "night owl" "burning oil" "past midnight" "wide awake" "moonlight coding")
  elif (( hour < 12 )); then
    greeting_pool+=("good morning" "rise and shine" "early bird" "morning coffee" "fresh start" "up with the sun")
  elif (( hour < 17 )); then
    greeting_pool+=("good afternoon" "midday grind" "keep going" "afternoon slump" "halfway there")
  elif (( hour < 21 )); then
    greeting_pool+=("good evening" "evening unwind" "winding down" "golden hour")
  else
    greeting_pool+=("good night" "night mode" "under the stars" "wrapping up" "stargazing")
  fi
  local greeting="${greeting_pool[$(( (RANDOM % ${#greeting_pool[@]}) + 1 ))]}"

  _wc_starline "$_WC_CONTENT_WIDTH" 142
  if [[ -f "$HOME/.config/wezterm/fonts/Terrace.flf" ]]; then
    # Terrace isn't a stock figlet font -- it's patorjk's own TAAG font,
    # bundled in shell/wezterm-fonts/ and installed to this path by
    # install.sh, since figlet only ships the classic font set.
    _wc_block iris "$(figlet -d "$HOME/.config/wezterm/fonts" -f Terrace -w 300 "$greeting" 2>/dev/null)"
  elif command -v figlet >/dev/null 2>&1; then
    _wc_block iris "$(figlet -f rectangles -k -w 300 "$greeting" 2>/dev/null)"
  else
    printf '  '
    _wc iris "$(_wc_fullwidth "$greeting")"
    printf '\n'
  fi
  printf '\n  '
  # No clock here -- the banner is a snapshot printed once when the tab
  # opens, so a time that stops ticking the moment you look away from it
  # would just read as wrong a few seconds later.
  _wc subtle "$(_wc_letterspace "$(date '+%A, %B %-d %Y' | tr '[:upper:]' '[:lower:]')")"
  printf '\n'
  printf '\n'

  local left_col right_col
  left_col=$(
    _wc_header "⚙" "system"
    _wc_system_info 24
    printf '\n'
    _wc_agent_usage_section 24
  )
  right_col=$(
    _wc_header "▤" "recent directories"
    _wc_recent_dirs_rows 27
  )
  _wc_two_column "$left_col" "$right_col"
  printf '\n'

  # A quote pulled at random each tab -- a mix of the genuinely inspirational
  # and the programmer-in-joke, kept lowercase to match the rest of the
  # banner's typography rather than forcing a transform on arbitrary famous
  # quotes (which mangles proper nouns). Trimmed to fit one box row.
  local -a quotes=(
    "simplicity is the soul of efficiency. — austin freeman"
    "there are only two hard things: cache invalidation and naming things. — phil karlton"
    "the best error message is the one that never shows up. — thomas fuchs"
    "may the source be with you."
    "it's not a bug, it's an undocumented feature."
    "talk is cheap. show me the code. — linus torvalds"
    "programs must be written for people to read, not just for machines. — hal abelson"
    "the only way to go fast is to go well. — robert c. martin"
    "premature optimization is the root of all evil. — donald knuth"
    "any sufficiently advanced technology is indistinguishable from magic. — arthur c. clarke"
    "code never lies, comments sometimes do. — ron jeffries"
    "weeks of coding can save you hours of planning."
    "ctrl+z is the closest thing we have to a time machine."
    "may your builds be green and your merges be clean."
    "do or do not, there is no try. — yoda"
    "it always seems impossible until it's done. — nelson mandela"
  )
  # Split "text — attribution" so the two can be styled differently -- the
  # quote itself in italic (a standard typographic convention for
  # quotations), the attribution smaller/dimmer, both bracketed in actual
  # opening+closing quote marks instead of just a leading one.
  local quote quote_text quote_attrib
  quote="${quotes[$(( (RANDOM % ${#quotes[@]}) + 1 ))]}"
  if [[ "$quote" == *" — "* ]]; then
    quote_text="${quote%% — *}"
    quote_attrib="${quote#*— }"
  else
    quote_text="$quote"
    quote_attrib=""
  fi
  printf '  '
  _wc gold "❝ "
  _wc text "$quote_text" "3"
  _wc gold " ❞"
  [[ -n "$quote_attrib" ]] && _wc subtle "  — ${quote_attrib}"
  printf '\n'
  printf '\n'

  # A rotating tip, mostly to reinforce muscle memory for the custom bindings.
  local -a tips=(
    "ctrl-space then | or -  splits a pane (cmd-d / cmd-shift-d also work)"
    "ctrl-space then h/j/k/l  moves between panes"
    "ctrl-space then z  zooms the focused pane"
    "ctrl-space then r  reloads this config after an edit"
    "new tabs (cmd-t) always start at ~; splits inherit the current directory"
  )
  printf '  '
  _wc iris "tip"
  _wc subtle "  ${tips[$(( (RANDOM % ${#tips[@]}) + 1 ))]}"
  printf '\n'
  _wc_starline "$_WC_CONTENT_WIDTH" 0
}

printf '\n'
_wc muted "$(printf '╭'; printf -- '─%.0s' {1..162}; printf '╮')"
printf '\n'
local _wc_body_text
_wc_body_text=$(_wc_render_body)
local -a _wc_body_lines
_wc_body_lines=("${(@f)_wc_body_text}")
local _wc_line
for _wc_line in "${_wc_body_lines[@]}"; do
  _wc_box_line "$_wc_line"
done
_wc muted "$(printf '╰'; printf -- '─%.0s' {1..162}; printf '╯')"
printf '\n\n'

unset -f _wc _wc_starline _wc_visible_width _wc_star_pad _wc_box_line _wc_pad_to _wc_two_column _wc_fullwidth _wc_block _wc_letterspace _wc_bar _wc_header _wc_os_version _wc_uptime _wc_loadavg _wc_mem_stats _wc_claude_usage _wc_codex_usage _wc_agent_usage_section _wc_system_info _wc_recent_dirs_rows _wc_render_body
unset _wc_rose _wc_fw _WC_CONTENT_WIDTH _WC_COL_WIDTH _WC_GAP
