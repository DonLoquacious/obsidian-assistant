#!/bin/bash

# Default to current directory if no argument provided
PROJECT_DIRECTORY="${1:-..}"

# Output file path
OUTPUT_JSON="./PROJECT_FILES_JSON"

# Ensure the project directory exists
if [[ ! -d "$PROJECT_DIRECTORY" ]]; then
  echo "Error: Project directory '$PROJECT_DIRECTORY' does not exist."
  exit 1
fi

# Ensure the output directory exists
OUTPUT_DIR=$(dirname "$OUTPUT_JSON")
mkdir -p "$OUTPUT_DIR"

# Initialize the JSON array
echo "[" > "$OUTPUT_JSON"

# Iterate over all .md files in the directory
first=true
for filepath in "$PROJECT_DIRECTORY"/*.md; do
  # Check if there are no .md files
  if [[ ! -e "$filepath" ]]; then
    echo "Error: No markdown (.md) files found in directory '$PROJECT_DIRECTORY'."
    echo "[]" > "$OUTPUT_JSON"
    exit 1
  fi

  # Get filename and content
  filename=$(basename "$filepath")
  content=$(<"$filepath")

  # Escape quotes and handle newlines
  content_json=$(echo "$content" | sed ':a;N;$!ba;s/"/\\"/g;s/\n/\\n/g')

  # Add a comma for elements after the first one
  if [[ "$first" == false ]]; then
    echo "," >> "$OUTPUT_JSON"
  else
    first=false
  fi

  # Write JSON entry
  echo "  {" >> "$OUTPUT_JSON"
  echo "    \"filename\": \"$filename\"," >> "$OUTPUT_JSON"
  echo "    \"content\": \"$content_json\"" >> "$OUTPUT_JSON"
  echo "  }" >> "$OUTPUT_JSON"
done

# Close the JSON array
echo "]" >> "$OUTPUT_JSON"

echo "Output saved to $OUTPUT_JSON"
