#!/bin/bash

# Ensure the API key is set
if [[ -f .env ]]; then
    source .env
else
    echo ".env file not found!"
    exit 1
fi

# Check if result.txt exists
if [[ ! -f result.txt ]]; then
    echo "result.txt not found!"
    exit 1
fi

# Read the content of result.txt
MESSAGE=$(cat result.txt)

# Preview the content of result.txt
echo -e "Preview of the message to be sent:\n"
echo "$MESSAGE"
echo

# Automatically send the message
# Prepare JSON payload
JSON_PAYLOAD=$(jq -n --arg text "$MESSAGE" '{text: $text}')

# Send the message to the webhook
RESPONSE=$(curl -s -X POST "$WEEKLY_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

# Check if the message was sent successfully
if [[ $? -eq 0 ]]; then
    echo "Message sent successfully."
else
    echo "Failed to send the message."
fi
