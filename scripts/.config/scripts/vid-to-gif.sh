#!/bin/sh

set -euo pipefail

SCALE=500
FPS=10

expand_tilde() {
  case "$1" in
    "~")   printf '%s' "$HOME" ;;
    "~/"*) printf '%s' "$HOME/${1#~/}" ;;
    *)     printf '%s' "$1" ;;
  esac
}

# Support both Automator (passes files as args) and direct CLI usage
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <input> [output] [fps] [scale]" >&2
  exit 1
fi

# When called from Automator Quick Action, files are passed as separate args.
# We treat the first arg as input, derive a default output from it if not given.
input="$(expand_tilde "$1")"
shift

# If next arg looks like a video/gif path (not a number), treat it as output
if [ "$#" -gt 0 ]; then
  case "$1" in
    [0-9]*) output="" ;;  # it's fps/scale, not an output path
    *)      output="$(expand_tilde "$1")"; shift ;;
  esac
fi

# Default output: same directory as input, same basename, .gif extension
if [ -z "${output:-}" ]; then
  dir="$(dirname "$input")"
  base="$(basename "$input")"
  name="${base%.*}"
  output="${dir}/${name}.gif"
fi

fps="${1:-$FPS}"
scale="${2:-$SCALE}"

echo "input=$input"
echo "output=$output"
echo "fps=$fps"
echo "scale=$scale"

ffmpeg -i "$input" \
    -vf "fps=$fps,scale=$scale:-1:flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    -loop 0 "$output"

# -ss 30 -t 3
# use above to skip 30s into vid and create gif for 3 seconds
