#!/bin/bash

API_URL="https://api.openai.com/v1"
AUTH_HEADER="Authorization: Bearer $OPENAI_API_KEY"
CONTENT_TYPE_HEADER="Content-Type: application/json"
BETA_HEADER="OpenAI-Beta: assistants=v2"
INSTRUCTIONS_FILE="./ASSISTANT_INSTRUCTIONS"
VECTOR_ID_FILE="./VECTOR_ID"

if [[ -z "$OPENAI_API_KEY" ]]; then
  echo "Error: Environment variable OPENAI_API_KEY is not set."
  exit 1
fi

if [[ ! -f "$INSTRUCTIONS_FILE" ]]; then
  echo "Error: The Assistant Instructions file is missing in the Assistants directory."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "jq is not installed. Attempting to install..."

  if sudo apt-get update && sudo apt-get install -y jq; then
    echo "jq successfully installed."
  else
    echo "Error: Failed to install jq. Please install it manually."
    exit 1
  fi
fi

if ! command -v curl &> /dev/null; then
  echo "curl is not installed. Attempting to install..."

  if sudo apt-get update && sudo apt-get install -y curl; then
    echo "jq successfully installed."
  else
    echo "Error: Failed to install jq. Please install it manually."
    exit 1
  fi
fi

get_config_value() {
  local key=$1
  grep "^${key}:" "$INSTRUCTIONS_FILE" | sed "s/${key}: *//"
}

name=$(get_config_value "name")
echo "Project name: $name"

if [ -f "$VECTOR_ID_FILE" ]; then
  vector_id=$(<"$VECTOR_ID_FILE")

else
  list_response=$(curl -s -X GET "$API_URL/vector_stores?order=desc&limit=20" \
                      -H "$CONTENT_TYPE_HEADER" \
                      -H "$AUTH_HEADER" \
                      -H "$BETA_HEADER")

  if ! echo "$list_response" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON response or no content when listing assistants."
    exit 1
  fi

  vector_id=$(echo "$list_response" | jq -r --arg name "$name" '.data | map(select(.name == $name) | .id) | first')
fi

if [ "$vector_id" == null ]; then
  payload=$(jq -n --arg name "$name" '{"name": $name}')
  create_response=$(curl -s -X POST -H "$AUTH_HEADER" \
                          -H "$CONTENT_TYPE_HEADER" \
                          -H "$BETA_HEADER" \
                          -d "$payload" \
                          "${API_URL}/vector_stores")

  if ! echo "$create_response" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON response or no content when creating vector store."
    exit 1
  fi

  vector_id=$(echo "$create_response" | jq -r '.id')
  echo "$vector_id" > "$VECTOR_ID_FILE"
fi

if [ -z "$vector_id" ]; then
  echo "Error: Vector store creation failed."
  exit 1
fi

get_file_size() {
  local file_path=$1
  stat --printf="%s" "$file_path"
}

existing_files=$(curl -s -H "$AUTH_HEADER" \
                        -H "$CONTENT_TYPE_HEADER" \
                        -H "$BETA_HEADER" \
                        "${API_URL}/files")

file_ids=
for file_path in ../*.md; do
  [ -e "$file_path" ] || continue

  echo "Handling local file: $file_path"

  file_name=$(basename "$file_path")
  echo "Uploaded file will have the full name of $file_name"

  file_info=$(echo "$existing_files" | jq -r --arg name "$file_name" '.data[] | select(.filename == $name)')
  local_usage_bytes=$(get_file_size "$file_path")

  if [ -n "$file_info" ]; then
    remote_usage_bytes=$(echo "$file_info" | jq -r '.bytes // empty' | head -n 1)
    file_id=$(echo "$file_info" | jq -r '.id // empty' | head -n 1)
  fi

  echo "Local usage bytes: $local_usage_bytes"
  echo "Remote usage bytes: $remote_usage_bytes"
  echo "Remote file ID: $file_id"

  if [ -n "$file_id" ]; then

    if [ "$local_usage_bytes" == "$remote_usage_bytes" ]; then
      echo "File found on remote server, and bytes match- skipping upload"
      file_ids="$file_ids$file_id
"
      continue
    fi

    echo "Deleting existing file and unlinking in vector store, to replace with updated copy"

    curl -s -X DELETE -H "$AUTH_HEADER" \
          -H "$CONTENT_TYPE_HEADER" \
          -H "$BETA_HEADER" \
          "${API_URL}/files/${file_id}"

    curl -s -X DELETE "${API_URL}/vector_stores/${vector_id}/files/${file_id}" \
          -H "$AUTH_HEADER" \
          -H "$CONTENT_TYPE_HEADER" \
          -H "$BETA_HEADER"
  fi

  upload_response=$(curl -s -X POST "${API_URL}/files" \
                          -H "$AUTH_HEADER" \
                          -F "purpose=assistants" \
                          -F "file=@$file_path")

  if ! echo "$upload_response" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON response or no content when uploading file '$file_name'"
    continue
  fi

  new_file_id=$(echo "$upload_response" | jq -r '.id')
  echo "File '$file_name' uploaded with new id $new_file_id"

  if [[ -z "$new_file_id" || "$new_file_id" == null ]]; then
    echo "File '$file_name' upload failed. Response: $upload_response"
    continue
  fi

  file_ids="$file_ids$new_file_id
"

  link_response=$(curl -s -X POST "${API_URL}/vector_stores/${vector_id}/files" \
                        -H "$AUTH_HEADER" \
                        -H "$CONTENT_TYPE_HEADER" \
                        -H "$BETA_HEADER" \
                        -d "{\"file_id\": \"$new_file_id\"}")

  if ! echo "$link_response" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON response or no content when linking file '$file_name' to vector store $vector_id"
    continue
  fi

  echo "File '$file_name' linked to vector store $vector_id"
done

file_ids=${file_ids%$'\n'}
echo "$file_ids" > ./VECTOR_FILE_IDS
