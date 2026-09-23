#!/bin/bash
set -euo pipefail
cd /home/hans/.openclaw/workspace/projects/rtorrent

# Cleanup any previous run
rm -f gource_pipe gource.mp4

# Create named pipe in workspace (avoids /tmp quota issue)
mkfifo gource_pipe

# Start gource writing PPM to the pipe (background)
gource -1920x1080 \
  --output-ppm-stream gource_pipe \
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
  . &
GOURCE_PID=$!

# Give gource a moment to open the pipe
sleep 2

# ffmpeg reads from the pipe and encodes H.264 MP4
ffmpeg -y \
  -framerate 60 \
  -i gource_pipe \
  -c:v libx264 \
  -preset fast \
  -crf 23 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  gource.mp4

FFMPEG_EXIT=$?

# Clean up gource and the pipe
kill $GOURCE_PID 2>/dev/null || true
wait $GOURCE_PID 2>/dev/null || true
rm -f gource_pipe

echo "FFMPEG_EXIT=$FFMPEG_EXIT"
if [ -f gource.mp4 ]; then
  ls -lh gource.mp4
else
  echo "ERROR: gource.mp4 not created"
  exit 1
fi
