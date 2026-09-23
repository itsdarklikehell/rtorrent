#!/bin/bash
set -euo pipefail
cd /home/hans/.openclaw/workspace/projects/rtorrent

rm -f gource_pipe gource.mp4
mkfifo gource_pipe

# Writer: gource PPM stream
(
  exec > gource_pipe
  gource -1280x720 \
    --output-ppm-stream - \
    --output-framerate 25 \
    --auto-skip-seconds 0.5 \
    --multi-sampling \
    --stop-at-end \
    --title "rtorrent" \
    --hide filenames \
    --hide progress \
    --file-idle-time 0 \
    --background-colour 000000 \
    --font-size 20 \
    --max-files 5000 \
    --seconds-per-day 0.02 \
    < <(git log --all --pretty=format:'%h|%an|%ae|%ad|%s' --date=short)
) &
GOURCE_PID=$!

sleep 1

# Reader: ffmpeg H.264 - preset medium voor betere kwaliteit bij kleine tijdschalen
ffmpeg -y \
  -framerate 25 \
  -i gource_pipe \
  -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2" \
  -c:v libx264 \
  -preset veryfast \
  -crf 23 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  gource.mp4 2>&1 | tail -3

FL=$?
wait $GOURCE_PID 2>/dev/null
rm -f gource_pipe

if [ -f gource.mp4 ] && [ $FL -eq 0 ]; then
  echo "=== RESULT ==="
  ls -lh gource.mp4
  ffprobe -v error -show_entries format=duration,size,bit_rate -show_entries stream=width,height,r_frame_rate,codec_name gource.mp4 || true
else
  echo "ERROR: ffmpeg exit=$FL"
  [ -f gource.mp4 ] && ls -lh gource.mp4 || true
  exit 1
fi
