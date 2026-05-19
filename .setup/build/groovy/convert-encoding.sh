#!/bin/bash
#########################################################
# Convert Groovy scripts to IBM-1047 encoding
# This script converts all .groovy files in the current
# directory from UTF-8 to IBM-1047 (EBCDIC) encoding
# required for z/OS USS execution
#########################################################

echo "Converting Groovy scripts to IBM-1047 encoding..."

for file in *.groovy; do
    if [ -f "$file" ]; then
        echo "  Converting: $file"
        # Tag as UTF-8 first
        chtag -tc UTF-8 "$file" 2>/dev/null || true
        # Convert to IBM-1047
        iconv -f UTF-8 -t IBM-1047 "$file" > "${file}.tmp"
        mv "${file}.tmp" "$file"
        # Tag as IBM-1047
        chtag -tc IBM-1047 "$file" 2>/dev/null || true
    fi
done

echo "Encoding conversion complete"

# Made with Bob
