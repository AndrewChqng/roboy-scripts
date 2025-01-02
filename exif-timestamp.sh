#!/bin/bash

# Ensure exiftool is installed
if ! command -v exiftool &> /dev/null; then
    echo "exiftool is required but not installed. Install it using your package manager."
    exit 1
fi

# Check if a directory was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

DIRECTORY="$1"

# Process all image and video files in the directory and its subdirectories
find "$DIRECTORY" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png"  -o -iname "*.heic"   -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" \) | while read -r FILE; do
    # Determine if the file is an image or video based on extension
    EXTENSION="${FILE##*.}"
    TAG=""

    case "$EXTENSION" in
        jpg|jpeg|png|heic)
            TAG="DateTimeOriginal"
            ;;
        mp4|mov|avi|mkv)
            TAG="CreateDate"
            ;;
        *)
            echo "Unsupported file type: $FILE"
            continue
            ;;
    esac

    # Extract the relevant date from metadata
    CREATION_DATE=$(exiftool -"$TAG" -s3 "$FILE" 2>/dev/null)

    if [ -n "$CREATION_DATE" ]; then
        # Convert from 'YYYY:MM:DD HH:MM:SS' to 'YYYY-MM-DD HH:MM:SS'
        FORMATTED_DATE=$(echo "$CREATION_DATE" | sed 's/:/-/; s/:/-/;')

        # Convert to a timestamp compatible with touch
        TIMESTAMP=$(date -d "$FORMATTED_DATE" +%Y%m%d%H%M.%S 2>/dev/null)

        if [ $? -eq 0 ]; then
            # Update the file's modification and access times
            touch -t "$TIMESTAMP" "$FILE"
            echo "Updated $FILE with date $CREATION_DATE"
        else
            echo "Invalid date format for $FILE: $CREATION_DATE"
        fi
    else
        echo "No $TAG metadata found for $FILE"
    fi
done
