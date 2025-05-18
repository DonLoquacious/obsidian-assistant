#!/bin/bash

API_URL="https://api.openai.com/v1"
AUTH_HEADER="Authorization: Bearer $OPENAI_API_KEY"
CONTENT_TYPE_HEADER="Content-Type: application/json"
BETA_HEADER="OpenAI-Beta: assistants=v2"
THREAD_ID_FILE="./SUMMARY_THREAD_ID"
VECTOR_ID_FILE="./VECTOR_ID"

if [[ -z "${OPENAI_API_KEY}" ]]; then
  echo "Error: OPENAI_API_KEY environment variable is not set."
  exit 1
fi

read -r -d '' instructions <<'EOF'
Please write a markdown file that summarizes the contents of every project file you have. For each file, start with its filename as a header and then provide a small summary. Each file summary should be no more than three paragraphs, with each paragraph containing no more than four sentences. Generate additional responses as needed to cover all files, and DO NOT condense these instructions—follow them exactly in every run until every file is summarized. When you have completed all summaries for all files, output the words SUMMARY OVER (in all caps) on a blank line by itself. Be sure to include newlines in your response as explicit \n so that I can parse it.
EOF

if [[ -z "$instructions" ]]; then
  echo "Error: The prompt for summary generation is empty."
  exit 1
fi

assistant_id=
if [ -f ./ASSISTANT_ID ]; then
  read -r assistant_id < ./ASSISTANT_ID
  echo "Assistant ID loaded from file: $assistant_id"
fi

if [ -z "$assistant_id" ]; then
  echo "Assistant ID could not be located- plrease run the update_assistant script first"
  exit 1
fi

vector_id=

if [ -f "$VECTOR_ID_FILE" ]; then
  vector_id=$(<"$VECTOR_ID_FILE")
  echo "Vector ID: $vector_id"
fi

if [ -z "$vector_id" ]; then
  echo "Vector store ID could not be located- plrease run the update_files script first"
  exit 1
fi

payload=$(jq -n \
  --arg assistant_id "$assistant_id" \
  --arg instructions "$instructions" \
  --arg vector_id "$vector_id" \
  --argjson stream true \
  '{
     assistant_id: $assistant_id,
     thread: {messages: [{role: "user", content: $instructions}]},
     tool_resources: {file_search: {vector_store_ids: [$vector_id]}},
     stream: $stream
  }')

if [[ -z "$payload" ]]; then
  echo "Error: Failed to construct payload."
  exit 1
fi

final_message=""
echo -n "Asking assistant AI to compile a summary of all project reference materials- please wait"
i=0
started=0

while IFS= read -r line; do
  if (( started == 0 )); then
    if (( i % 2 == 0 )); then 
      echo -n "..."
    else
      echo -n $'\b\b\b   \b\b\b'
    fi
    ((i++))
  fi

  if [[ "$line" =~ ^event:\ (.+)$ ]]; then
    last_event="${BASH_REMATCH[1]}"

  elif [[ "$line" =~ ^data:\ (.+)$ ]]; then
    data_content="${BASH_REMATCH[1]}"

    if [[ "$last_event" == "thread.message.delta" ]]; then
      raw_text=$(echo "$data_content" | jq -r '.delta.content[]?.text.value' 2>/dev/null || echo "")
      text_piece=$(printf "%b" "$raw_text")

      if [ "$text_piece" != "null" ]; then
        final_message+="$text_piece"

        if (( started == 0 )); then
          printf "\n"
          started=1
        fi

        printf "$text_piece"
      fi
    fi

    last_event=""
  fi
done < <(curl -s -N -X POST "${API_URL}/threads/runs" \
                -H "$CONTENT_TYPE_HEADER" \
                -H "$AUTH_HEADER" \
                -H "$BETA_HEADER" \
                -d "$payload" || { echo "Error: Streaming run failed."; exit 1; })

if [ -z "$final_message" ]; then
  echo "\nError: A problem occurred with OpenAI. Out of credits?"
  exit 1
fi

output_file="./PROJECT_SUMMARY"
printf "%b" "$final_message" > "$output_file"
echo "Final message written to $output_file"
