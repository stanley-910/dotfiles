#!/bin/sh

set -euo pipefail

input="${1:?Usage: $0 <path>}"

# expand ~ only if it is at the start
case "$input" in
  "~") input="$HOME" ;;
  "~/"*) input="$HOME/${input#~/}" ;;
esac


output="${2:?Usage: $0 <path>}"

# expand ~ only if it is at the start
case "$output" in
  "~") output="$HOME" ;;
  "~/"*) output="$HOME/${output#~/}" ;;
esac

SCALE=500
FPS=10

fps="${3:-$FPS}"
scale="${4:-$SCALE}"

echo "fps=$fps"
echo "scale=$scale"


ffmpeg -i "$input" \
    -vf "fps=$fps,scale=$scale:-1:flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    -loop 0 "$output"


# -ss 30 -t 3 
# use above to skip 30s into vid and create gif for 3 seconds 
