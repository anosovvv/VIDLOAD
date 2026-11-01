#!/bin/zsh
# Fetches the exact third-party command line tools shipped by VIDLOAD 1.0.0.
# This is only for developers building from source. End users should download
# the ready-to-run ZIP from GitHub Releases instead.

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle_dir="$project_root/VIDLOAD/Resources/VIDLOADTools.bundle"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

yt_dlp_url="https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.26/yt-dlp_macos"
arm64_url="https://registry.npmjs.org/@dfloresc/ffmpeg-macos-lgpl-arm64/-/ffmpeg-macos-lgpl-arm64-9.0.1-1.tgz"
x64_url="https://registry.npmjs.org/@dfloresc/ffmpeg-macos-lgpl-x64/-/ffmpeg-macos-lgpl-x64-9.0.1-1.tgz"
arm64_integrity="SSFe4diu+OZjdzF4M+J3Ip1vjR53gVUdawpHnZ5N1+5Sab+VfeJ8rxnEOUe7JfGuv1oSkBhyxY3gDEOQ5010Xg=="
x64_integrity="rV0gxgpjkTKABk2h6UI9KmeU6uoXcGZ1GZwNd8zlk7vM9yLEgksMzt2/hE4QRTLty3ydUVDGyjd5TM6oTumw4w=="

curl -L --fail --silent --show-error "$yt_dlp_url" -o "$temp_dir/yt-dlp"
curl -L --fail --silent --show-error "$arm64_url" -o "$temp_dir/arm64.tgz"
curl -L --fail --silent --show-error "$x64_url" -o "$temp_dir/x64.tgz"

[[ "$(openssl dgst -sha512 -binary "$temp_dir/arm64.tgz" | base64)" == "$arm64_integrity" ]]
[[ "$(openssl dgst -sha512 -binary "$temp_dir/x64.tgz" | base64)" == "$x64_integrity" ]]

rm -rf "$bundle_dir"
mkdir -p "$bundle_dir/bin" "$bundle_dir/arm64" "$bundle_dir/x86_64"
mv "$temp_dir/yt-dlp" "$bundle_dir/bin/yt-dlp"
tar -xzf "$temp_dir/arm64.tgz" -C "$bundle_dir/arm64" --strip-components=1
tar -xzf "$temp_dir/x64.tgz" -C "$bundle_dir/x86_64" --strip-components=1
chmod 755 "$bundle_dir/bin/yt-dlp" \
  "$bundle_dir/arm64/bin/ffmpeg" "$bundle_dir/arm64/bin/ffprobe" \
  "$bundle_dir/x86_64/bin/ffmpeg" "$bundle_dir/x86_64/bin/ffprobe"

# YouTube requires a JavaScript runtime even when yt-dlp bundles its EJS scripts.
for pair in "arm64:aarch64" "x86_64:x86_64"; do
  architecture="${pair%%:*}"
  target="${pair##*:}"
  curl -L --fail --silent --show-error "https://github.com/denoland/deno/releases/download/v2.9.8/deno-${target}-apple-darwin.zip" -o "$temp_dir/deno-${architecture}.zip"
  unzip -qo "$temp_dir/deno-${architecture}.zip" -d "$temp_dir/deno-${architecture}"
  cp "$temp_dir/deno-${architecture}/deno" "$bundle_dir/$architecture/bin/deno"
  chmod 755 "$bundle_dir/$architecture/bin/deno"
done
curl -L --fail --silent --show-error "https://raw.githubusercontent.com/denoland/deno/v2.9.8/LICENSE.md" -o "$bundle_dir/DENO-LICENSE.md"
cp "$project_root/THIRD_PARTY_NOTICES.md" "$bundle_dir/THIRD_PARTY_NOTICES.txt"

echo "VIDLOAD tools are ready in $bundle_dir"
