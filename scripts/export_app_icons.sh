#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
root="$PWD"
ios_source="$root/Design/AppIcon/mumla-rams-ios-source.png"
mac_source="$root/Design/AppIcon/mumla-rams-mac-source.png"
ios_catalog="$root/Apps/iOS/Mumla/Resources/Assets.xcassets/AppIcon.appiconset"
mac_catalog="$root/Apps/macOS/Mumla/Resources/Assets.xcassets/AppIcon.appiconset"

sips -z 1024 1024 "$ios_source" --out "$ios_catalog/AppIcon-1024.png" >/dev/null
for size in 16 32 64 128 256 512 1024; do
  sips -z "$size" "$size" "$mac_source" --out "$mac_catalog/AppIcon-$size.png" >/dev/null
done
printf 'Exported iOS and macOS AppIcon assets.\n'
