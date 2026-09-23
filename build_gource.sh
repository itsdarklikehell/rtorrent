#!/bin/bash
set -euo pipefail
cd /home/hans/.openclaw/workspace/projects/rtorrent
rm -f gource_pipe gource.mp4
mkfifo gource_pipe

# Writer: gource produces PPM stream
(
  exec > gource_pipe
  gource -1920x1080 \
    --output-ppm-stream - \
    --output-framerate 60 \
    --auto-skip-seconds 0.5 \
    --multi-sampling \
    --stop-at-end \
    --title "rtorrent" \
    --hide filenames \
    --hide progress \
    --file-idle-time 0 \
    --background-colour 000000 \
    --font-size 24 \
    --max-files 5000 \
    --seconds-per-day 1 \
    < <(git log --all --pretty=format:'%h|%an|%ae|%ad|%s' --date=short)
) &
GOURCE_PID=$!

sleep 1

# Reader: ffmpeg encodes PPM stream to H.264 MP4
ffmpeg -y \
  -framerate 60 \
  -i gource_pipe \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
  -c:v libx264 \
  -preset fast \
  -crf 23 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  gource.mp4 2>&1 | tail -5

echo "FFMPEG_EXIT=$?"

wait $GOURCE_PID 2>/dev/null
echo "GOURCE_EXIT=$?"

rm -f gource_pipe
ls -lh gource.mp4
