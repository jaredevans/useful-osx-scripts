#!/bin/bash

clear

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 pattern [pattern ...]"
    exit 1
fi

for target in "$@"; do
    # Compatible find for macOS and Linux; escapes parentheses
    found_files=$(find . \( -name bin -o -name Library   -o -name Pictures  -o -name '.local' -o -name '.ssh' -o -name '.Trash' -o -name '.tldrc' -o -name '.cache' -o -name '.lmstudio' -o -name '.nvm' -o -name include -o -name lib -o -name dist -o -name node_modules \) -prune -o -type f -name "*${target}*" -print)

    if [ -z "$found_files" ]; then
        echo "No files found matching pattern: $target"
    else
        while IFS= read -r file; do
            if [[ "$file" == *"__"* ]]; then
                continue
            fi
            if command -v realpath &> /dev/null; then
                full_path=$(realpath "$file")
            else
                full_path=$(readlink -f "$file")
            fi
            if [[ "$full_path" == *"__"* ]]; then
                continue
            fi

            echo " "
            echo "------------------------"
            echo "File: $full_path"
            echo "------------------------"
	    if grep -Iq . "$file"; then
                cat "$file"
            fi
        done <<< "$found_files"
    fi
done

