#!/bin/bash

# Check if a year was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <year>"
    exit 1
fi

YEAR=$1

# Validate the year input (must be a 4-digit number)
if ! [[ "$YEAR" =~ ^[0-9]{4}$ ]]; then
    echo "Invalid year format. Please provide a 4-digit year."
    exit 1
fi

# Define English and Chinese month names
ENGLISH_MONTHS=("January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December")
CHINESE_MONTHS=("一月" "二月" "三月" "四月" "五月" "六月" "七月" "八月" "九月" "十月" "十一月" "十二月")

# Create folders for each month
for i in {0..11}; do
    MONTH=$(printf "%02d" $((i + 1)))
    ENGLISH_MONTH=${ENGLISH_MONTHS[$i]}
    CHINESE_MONTH=${CHINESE_MONTHS[$i]}
    FOLDER_NAME="${ENGLISH_MONTH} ${CHINESE_MONTH} ${YEAR}"
    mkdir -p "$FOLDER_NAME"
    echo "Created folder: $FOLDER_NAME"
done

echo "All 12 months for $YEAR have been created with English and Chinese names."
