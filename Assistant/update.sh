#!/bin/bash

ASSISTANT_FILE="ASSISTANT_INSTRUCTIONS"
ERROR_MSG="Error parsing Assistant/ASSISTANT_INSTRUCTIONS- please fill it out properly, or delete the file and it will be regenerated from the template."

if [ ! -f "$ASSISTANT_FILE" ]; then
    cp ../Templates/assistant_instructions_template.md "$ASSISTANT_FILE"
    echo "First run detected. Assistant instructions have been generated from the template- please open the Assistant/ASSISTANT_INSTRUCTIONS file in Obsidian and fill out the details before re-running."
    exit 0
fi

if grep -Fq "[" "$ASSISTANT_FILE" || grep -Fq "]" "$ASSISTANT_FILE"; then
    echo "$ERROR_MSG"
    exit 1
fi

name_value=$(grep "^name:" "$ASSISTANT_FILE" | sed 's/^name:[[:space:]]*//' | xargs)
model_value=$(grep "^model:" "$ASSISTANT_FILE" | sed 's/^model:[[:space:]]*//' | xargs)

if [ -z "$name_value" ] || [ -z "$model_value" ]; then
    echo "$ERROR_MSG"
    exit 1
fi

echo "Assistant instructions accepted- updating project files that assistant will use."

./update_files.sh
if [ $? -ne 0 ]; then
    echo "Error: Please fix the issues indicated in the update_files script."
    exit 1
fi

echo "Project files updated successfully- updating assistant configuration and resources."

./update_assistant.sh
if [ $? -ne 0 ]; then
    echo "Error: Please fix the issues indicated in the update_assistant script."
    exit 1
fi

echo "The assistant and all project files have been updated successfully! Have a nice day. =)"
exit 0
