#!/usr/bin/env bash

echo "deleting old files"
find . -type f \( -name "${1}_monochrome.png" -o -name "${1}_foreground.png" \) -print -delete

find . -type f -name "ic_launcher_monochrome.png" | while read -r f; do
    mv -v "$f" "$(dirname "$f")/${1}_monochrome.png"
done

find . -type f -name "ic_launcher_foreground.png" | while read -r f; do
    mv -v "$f" "$(dirname "$f")/${1}_foreground.png"
done