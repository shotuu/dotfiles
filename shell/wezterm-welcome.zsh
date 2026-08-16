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
# has to (the figlet greeting for "good afternoon, daniel") comes in at 92,
# so this leaves a couple of columns of slack.
typeset -gi _WC_CONTENT_WIDTH=94

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

# Wraps one already-colored line in the box border, padding it out to
# _WC_CONTENT_WIDTH. Padding isn't just blank space: most of it is, but
# some columns get a dim star glyph instead, so the sky shows up next to
# real content and not only on the dedicated starline rows.
_wc_box_line() {
  local raw=$1
  local visible pad_needed
  visible=$(_wc_visible_width "$raw")
  pad_needed=$(( _WC_CONTENT_WIDTH - visible ))
  (( pad_needed < 0 )) && pad_needed=0

  local -a glyphs=('.' '·' '+' '✦' '*' '˙')
  local -A pad_star_at
  local num_stars=0
  if (( pad_needed >= 6 )); then
    num_stars=$(( pad_needed / 20 ))
    (( RANDOM % 100 < 40 )) && num_stars=$(( num_stars + 1 ))
    (( num_stars > 5 )) && num_stars=5
  fi
  local placed=0 pos tries=0
  while (( placed < num_stars && tries < 25 )); do
    pos=$(( (RANDOM % pad_needed) + 1 ))
    tries=$(( tries + 1 ))
    [[ -n "${pad_star_at[$pos]}" ]] && continue
    pad_star_at[$pos]="${glyphs[$(( (RANDOM % ${#glyphs[@]}) + 1 ))]}"
    (( placed++ ))
  done

  _wc muted "│"
  printf ' %s' "$raw"
  local pi roll
  for (( pi = 1; pi <= pad_needed; pi++ )); do
    if [[ -n "${pad_star_at[$pi]}" ]]; then
      roll=$(( RANDOM % 3 ))
      if (( roll == 0 )); then
        _wc gold "${pad_star_at[$pi]}"
      elif (( roll == 1 )); then
        _wc text "${pad_star_at[$pi]}"
      else
        _wc subtle "${pad_star_at[$pi]}"
      fi
    else
      printf ' '
    fi
  done
  printf ' '
  _wc muted "│"
  printf '\n'
}

# Fullwidth Unicode forms (U+FF00 block) render as double-width in a
# monospace terminal -- the fallback greeting style if figlet isn't
# installed. Only covers the letters the greeting phrases and ", daniel"
# ever use; anything else (spaces) passes through unchanged.
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
  _wc subtle "$(printf '%-9s' 'host')"
  _wc foam "$host"
  printf '\n'

  printf '  '
  _wc subtle "$(printf '%-9s' 'system')"
  _wc foam "$os_name"
  _wc muted "  ·  "
  _wc text "$shell_info"
  if [[ -n "$uptime_str" ]]; then
    _wc muted "  ·  up "
    _wc text "$uptime_str"
  fi
  if [[ -n "$load_str" ]]; then
    _wc muted "  ·  load "
    _wc text "$load_str"
  fi
  printf '\n'

  local mem_line mem_pct mem_used mem_total
  mem_line=$(_wc_mem_stats)
  if [[ -n "$mem_line" ]]; then
    IFS='|' read -r mem_pct mem_used mem_total <<<"$mem_line"
    printf '  '
    _wc subtle "$(printf '%-9s' 'memory')"
    _wc_bar "$mem_pct" 25 "${mem_used} / ${mem_total} gb"
    printf '\n'
  fi

  local disk_pct_num
  disk_pct_num=$(df -H "$HOME" 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')
  if [[ -n "$disk_pct_num" ]]; then
    printf '  '
    _wc subtle "$(printf '%-9s' 'disk')"
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
    _wc subtle "$(printf '%-9s' 'battery')"
    _wc_bar "$battery_pct" 25 "$battery_state"
    printf '\n'
  fi
}

# Most-recently-visited directories, deduplicated and numbered so they line
# up with the `j <n>` / `jj` jump commands defined in zshrc-managed-block.zsh
# (tracked via a chpwd hook into $RECENT_DIRS_FILE -- see that file for why
# this isn't sourced from zoxide). Bar length decays by rank rather than a
# real score, since a recency-ordered list has no score to chart, only an
# order.
_wc_recent_dirs() {
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
    rnames+=("$rname")
    (( ${#rname} > rname_width )) && rname_width=${#rname}
  done

  for (( ri = 1; ri <= rcount; ri++ )); do
    rbarlen=$(( 22 - (ri - 1) * 22 / rcount ))
    (( rbarlen < 1 )) && rbarlen=1
    rbar=""
    for (( rj = 0; rj < rbarlen; rj++ )); do rbar+="█"; done
    for (( rj = rbarlen; rj < 22; rj++ )); do rbar+="░"; done
    printf '  '
    _wc iris "$(printf '%2d' "$ri")"
    printf '  '
    _wc text "$(printf '%-*s' "$rname_width" "${rnames[ri]}")"
    printf '  '
    _wc iris "$rbar"
    printf '\n'
  done

  printf '\n  '
  _wc subtle "j <n>"
  _wc subtle " jumps to a number above"
  if command -v fzf >/dev/null 2>&1; then
    _wc muted "   ·   "
    _wc subtle "jj"
    _wc subtle " fuzzy-picks the same list"
  fi
  printf '\n'
}

# Everything between the box borders, unwrapped -- _wc_box_line pads and
# frames each line of this afterward. Kept as its own function so its
# output can be captured as one string and split back into lines.
_wc_render_body() {
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

  _wc_starline "$_WC_CONTENT_WIDTH" 84
  if command -v figlet >/dev/null 2>&1; then
    _wc_block iris "$(figlet -f smshadow -w 200 "${greeting}, daniel" 2>/dev/null)"
  else
    printf '  '
    _wc iris "$(_wc_fullwidth "${greeting}, daniel")"
    printf '\n'
  fi
  printf '\n  '
  # No clock here -- the banner is a snapshot printed once when the tab
  # opens, so a time that stops ticking the moment you look away from it
  # would just read as wrong a few seconds later.
  _wc subtle "$(_wc_letterspace "$(date '+%A, %B %-d %Y' | tr '[:upper:]' '[:lower:]')")"
  printf '\n'
  printf '\n'

  _wc_header "system"
  _wc_system_info
  printf '\n'

  _wc_header "recent directories"
  _wc_recent_dirs
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
  printf '  '
  _wc gold "❝ "
  _wc text "${quotes[$(( (RANDOM % ${#quotes[@]}) + 1 ))]}"
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
_wc muted "$(printf '╭'; printf -- '─%.0s' {1..96}; printf '╮')"
printf '\n'
local _wc_body_text
_wc_body_text=$(_wc_render_body)
local -a _wc_body_lines
_wc_body_lines=("${(@f)_wc_body_text}")
local _wc_line
for _wc_line in "${_wc_body_lines[@]}"; do
  _wc_box_line "$_wc_line"
done
_wc muted "$(printf '╰'; printf -- '─%.0s' {1..96}; printf '╯')"
printf '\n\n'

unset -f _wc _wc_starline _wc_visible_width _wc_box_line _wc_fullwidth _wc_block _wc_letterspace _wc_bar _wc_header _wc_os_version _wc_uptime _wc_loadavg _wc_mem_stats _wc_system_info _wc_recent_dirs _wc_render_body
unset _wc_rose _wc_fw _WC_CONTENT_WIDTH
