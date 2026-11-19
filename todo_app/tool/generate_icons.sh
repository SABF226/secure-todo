#!/usr/bin/env bash
# Regenerate every launcher/web/iOS icon from the three brand SVGs.
#
# Swap the artwork by editing (or replacing) these files, then run:
#   ./tool/generate_icons.sh
#
#   assets/branding/app_icon.svg             rounded square  (Android legacy, web any, favicon)
#   assets/branding/app_icon_foreground.svg  transparent     (Android adaptive foreground)
#   assets/branding/app_icon_maskable.svg    full bleed      (iOS, web maskable)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

svg="assets/branding/app_icon.svg"
fg="assets/branding/app_icon_foreground.svg"
maskable="assets/branding/app_icon_maskable.svg"

png() { # png <source> <size> <destination>
  inkscape "$1" --export-type=png --export-filename="$3" --export-width="$2" >/dev/null 2>&1
  echo "  $3 (${2}px)"
}

echo "Android legacy + adaptive icons"
# density: mdpi 1x, hdpi 1.5x, xhdpi 2x, xxhdpi 3x, xxxhdpi 4x
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  d="${pair%%:*}"; s="${pair##*:}"
  res="android/app/src/main/res/mipmap-$d"
  mkdir -p "$res"
  png "$svg" "$s" "$res/ic_launcher.png"
done

for pair in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  d="${pair%%:*}"; s="${pair##*:}"
  res="android/app/src/main/res/mipmap-$d"
  mkdir -p "$res"
  png "$fg" "$s" "$res/ic_launcher_foreground.png"
  cp "$res/ic_launcher_foreground.png" "$res/ic_launcher_monochrome.png"
  echo "  $res/ic_launcher_monochrome.png"
done

echo "iOS"
ios="ios/Runner/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ios" ]; then
  for pair in \
    Icon-App-20x20@1x:20 Icon-App-20x20@2x:40 Icon-App-20x20@3x:60 \
    Icon-App-29x29@1x:29 Icon-App-29x29@2x:58 Icon-App-29x29@3x:87 \
    Icon-App-40x40@1x:40 Icon-App-40x40@2x:80 Icon-App-40x40@3x:120 \
    Icon-App-60x60@2x:120 Icon-App-60x60@3x:180 \
    Icon-App-76x76@1x:76 Icon-App-76x76@2x:152 \
    Icon-App-83.5x83.5@2x:167 Icon-App-1024x1024@1x:1024; do
    name="${pair%%:*}"; s="${pair##*:}"
    png "$maskable" "$s" "$ios/$name.png"
  done
fi

echo "Web"
png "$svg" 32 web/favicon.png
png "$svg" 192 web/icons/Icon-192.png
png "$svg" 512 web/icons/Icon-512.png
png "$maskable" 192 web/icons/Icon-maskable-192.png
png "$maskable" 512 web/icons/Icon-maskable-512.png

echo "Done."
