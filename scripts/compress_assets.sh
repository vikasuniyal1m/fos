#!/usr/bin/env bash
# -------------------------------------------------
# compress_assets.sh – shrink images & videos
# -------------------------------------------------
set -e

# ---------- PNG compression ----------
if command -v pngquant >/dev/null; then
  echo "Compressing PNGs..."
  find ./assets/images -name "*.png" -exec pngquant --quality=65-80 --ext .png --force {} +
else
  echo "⚠️ pngquant not installed – skipping PNG compression."
fi

# ---------- JPEG compression ----------
if command -v jpegoptim >/dev/null; then
  echo "Compressing JPEGs..."
  find ./assets/images -name "*.jpg" -exec jpegoptim --max=80 --strip-all {} +
else
  echo "⚠️ jpegoptim not installed – skipping JPEG compression."
fi

# ---------- Video compression ----------
if command -v ffmpeg >/dev/null; then
  echo "Compressing MP4 videos..."
  for f in ./assets/videos/*.mp4; do
    [ -e "$f" ] || continue
    ffmpeg -i "$f" -vcodec libx264 -crf 28 -preset veryslow "${f%.mp4}_compressed.mp4"
    mv "${f%.mp4}_compressed.mp4" "$f"
  done
else
  echo "⚠️ ffmpeg not installed – skipping video compression."
fi

echo "✅ Asset compression finished."
