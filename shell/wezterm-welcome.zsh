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

_wc() {
  local hex=$_wc_rose[$1]
  local r=$((16#${hex:1:2})) g=$((16#${hex:3:2})) b=$((16#${hex:5:2}))
  printf '\033[38;2;%d;%d;%dm%s\033[0m' "$r" "$g" "$b" "$2"
}

# A night-sky line: densely scattered star glyphs, mostly dim `subtle` with
# a scattering of brighter `text` and warm `gold` ones mixed in so it reads
# as varied and alive rather than a flat wash of one color. `moon_col`, when
# >0, places a moon emoji (a real double-width glyph reads as an actual
# moon at a glance, unlike hand-drawn block art) -- reserving the column
# after it too, since the emoji occupies two terminal cells.
_wc_starline() {
  local width=$1 moon_col=$2
  local -a glyphs=('.' '·' '+' '✦' '*' '˙')
  local -A star_at
  local n placed col i roll
  n=$(( (RANDOM % 6) + 16 ))
  placed=0
  while (( placed < n )); do
    col=$(( (RANDOM % (width - 6)) + 2 ))
    (( moon_col > 0 && ( col == moon_col || col == moon_col + 1 ) )) && continue
    [[ -n "${star_at[$col]}" ]] && continue
    star_at[$col]="${glyphs[$(( (RANDOM % ${#glyphs[@]}) + 1 ))]}"
    (( placed++ ))
  done
  printf '  '
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

# Fullwidth Unicode forms (U+FF00 block) render as double-width in a
# monospace terminal, which is what actually makes text look "bigger"
# without falling back to multi-row block-letter art. Only covers the
# letters the greeting phrases and ", daniel" ever use; anything else
# (spaces) passes through unchanged.
typeset -A _wc_fw=(
  a "ａ" d "ｄ" e "ｅ" f "ｆ" g "ｇ" h "ｈ" i "ｉ" l "ｌ" m "ｍ"
  n "ｎ" o "ｏ" p "ｐ" r "ｒ" s "ｓ" t "ｔ" u "ｕ" v "ｖ" "," "，"
)

_wc_fullwidth() {
  local word=$1 i ch out=""
  for (( i = 1; i <= ${#word}; i++ )); do
    ch="${word[$i]}"
    out+="${_wc_fw[$ch]:-$ch}"
  done
  printf '%s' "$out"
}

# Colors and indents a multi-line block as a unit (one SGR code covering
# every line, rather than re-emitting it per line) -- used for the figlet
# greeting, which is several rows tall.
_wc_block() {
  local color=$1 text=$2 hex r g b line
  hex=$_wc_rose[$color]
  r=$((16#${hex:1:2})) g=$((16#${hex:3:2})) b=$((16#${hex:5:2}))
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
  while IFS= read -r line; do
    printf '  %s\n' "$line"
  done <<<"$text"
  printf '\033[0m'
}

# "g o o d   e v e n i n g" -- regular-width letter-spacing for the smaller
# subheading text (date/time), where fullwidth would look oversized.
_wc_letterspace() {
  local word=$1 i out=""
  for (( i = 1; i <= ${#word}; i++ )); do
    out+="${word[$i]} "
  done
  printf '%s' "$out"
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

# Small colored bullet + label, used identically above every section so the
# banner reads as one consistent structure rather than differently-styled
# blocks stitched together.
_wc_header() {
  printf '  '
  _wc iris "· "
  _wc subtle "$1"
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

_wc_system_info() {
  local host os_name shell_info uptime_str load_str
  host=$(hostname -s 2>/dev/null)
  host=${(L)host}
  os_name=$(_wc_os_version)
  os_name=${(L)os_name}
  shell_info="zsh ${ZSH_VERSION:-?}"
  uptime_str=$(_wc_uptime)
  load_str=$(_wc_loadavg)

  printf '  '
  _wc muted "$(printf '%-9s' 'host')"
  _wc foam "$host"
  printf '\n'

  printf '  '
  _wc muted "$(printf '%-9s' 'system')"
  _wc foam "$os_name"
  _wc highlight_med "  ·  "
  _wc text "$shell_info"
  if [[ -n "$uptime_str" ]]; then
    _wc highlight_med "  ·  up "
    _wc text "$uptime_str"
  fi
  if [[ -n "$load_str" ]]; then
    _wc highlight_med "  ·  load "
    _wc text "$load_str"
  fi
  printf '\n'

  local mem_line mem_pct mem_used mem_total
  mem_line=$(_wc_mem_stats)
  if [[ -n "$mem_line" ]]; then
    IFS='|' read -r mem_pct mem_used mem_total <<<"$mem_line"
    printf '  '
    _wc muted "$(printf '%-9s' 'memory')"
    _wc_bar "$mem_pct" 25 "${mem_used} / ${mem_total} gb"
    printf '\n'
  fi

  local disk_pct_num
  disk_pct_num=$(df -H "$HOME" 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')
  if [[ -n "$disk_pct_num" ]]; then
    printf '  '
    _wc muted "$(printf '%-9s' 'disk')"
    _wc_bar "$disk_pct_num" 25 "used"
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
    _wc muted "$(printf '%-9s' 'battery')"
    _wc_bar "$battery_pct" 25 "$battery_state"
    printf '\n'
  fi
}

# Most-frecent zoxide directories as a horizontal bar chart, scaled
# relative to the top entry's score.
_wc_frequent_dirs() {
  command -v zoxide >/dev/null 2>&1 || return 0
  local -a zlines
  zlines=("${(@f)$(zoxide query -l -s 2>/dev/null | sort -rn | head -n 6)}")
  (( ${#zlines[@]} == 0 )) && return 0

  local -a znames zscores
  local zline zscore zpath zname zi zj zbarlen zbar zmax=0 zname_width=0
  for zline in "${zlines[@]}"; do
    # zoxide right-pads scores with leading spaces for column alignment;
    # `read` skips that leading whitespace for us and, since zpath is the
    # last variable, still keeps spaces inside paths like "All Files".
    IFS=$' \t' read -r zscore zpath <<<"$zline"
    zname="${zpath:t}"
    zname=${(L)zname}
    znames+=("$zname")
    zscores+=("${zscore%.*}")
    (( ${zscore%.*} > zmax )) && zmax=${zscore%.*}
    (( ${#zname} > zname_width )) && zname_width=${#zname}
  done
  (( zmax == 0 )) && zmax=1

  for (( zi = 1; zi <= ${#znames[@]}; zi++ )); do
    zbarlen=$(( zscores[zi] * 24 / zmax ))
    (( zbarlen < 1 )) && zbarlen=1
    zbar=""
    for (( zj = 0; zj < zbarlen; zj++ )); do zbar+="█"; done
    for (( zj = zbarlen; zj < 24; zj++ )); do zbar+="░"; done
    printf '  '
    _wc text "$(printf '%-*s' "$zname_width" "${znames[zi]}")"
    printf '  '
    _wc iris "$zbar"
    _wc muted "  ${zscores[zi]}"
    printf '\n'
  done
}

# Greeting, keyed off time of day.
local hour greeting
hour=$(date +%H)
if (( hour < 5 )); then
  greeting="still up"
elif (( hour < 12 )); then
  greeting="good morning"
elif (( hour < 17 )); then
  greeting="good afternoon"
elif (( hour < 21 )); then
  greeting="good evening"
else
  greeting="good night"
fi

printf '\n'
_wc_starline 92 82
printf '\n'
if command -v figlet >/dev/null 2>&1; then
  _wc_block iris "$(figlet -f small -w 200 "${greeting}, daniel" 2>/dev/null)"
else
  printf '  '
  _wc iris "$(_wc_fullwidth "${greeting}, daniel")"
  printf '\n'
fi
printf '\n  '
_wc subtle "$(_wc_letterspace "$(date '+%A, %B %-d %Y  ·  %H:%M:%S' | tr '[:upper:]' '[:lower:]')")"
printf '\n'
_wc_starline 92 0
printf '\n'

_wc_header "system"
_wc_system_info
printf '\n'
_wc_starline 92 0
printf '\n'

_wc_header "frequent directories"
_wc_frequent_dirs
printf '\n'
_wc_starline 92 0
printf '\n'

# A quote pulled at random each tab -- a mix of the genuinely inspirational
# and the programmer-in-joke, kept lowercase to match the rest of the
# banner's typography rather than forcing a transform on arbitrary famous
# quotes (which mangles proper nouns).
local -a quotes=(
  "simplicity is the soul of efficiency. — austin freeman"
  "there are only two hard things in computer science: cache invalidation and naming things. — phil karlton"
  "the best error message is the one that never shows up. — thomas fuchs"
  "may the source be with you."
  "it's not a bug, it's an undocumented feature."
  "talk is cheap. show me the code. — linus torvalds"
  "programs must be written for people to read, and only incidentally for machines to execute. — hal abelson"
  "the only way to go fast is to go well. — robert c. martin"
  "premature optimization is the root of all evil. — donald knuth"
  "any sufficiently advanced technology is indistinguishable from magic. — arthur c. clarke"
  "code never lies, comments sometimes do. — ron jeffries"
  "weeks of coding can save you hours of planning."
  "ctrl+z is the closest thing we have to a time machine."
  "may your builds be green and your merges be clean."
  "do or do not, there is no try. — yoda"
  "the two most important days in your life are the day you are born and the day you find out why. — mark twain"
)
printf '  '
_wc gold "❝ "
_wc text "${quotes[$(( (RANDOM % ${#quotes[@]}) + 1 ))]}"
printf '\n\n'

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
_wc_starline 92 0
printf '\n\n'

unset -f _wc _wc_starline _wc_fullwidth _wc_letterspace _wc_bar _wc_header _wc_os_version _wc_uptime _wc_loadavg _wc_mem_stats _wc_system_info _wc_frequent_dirs
unset _wc_rose _wc_fw
