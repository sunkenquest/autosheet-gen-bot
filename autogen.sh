#!/bin/bash

# Ensure the API key is set
# if [[ -f .env ]]; then
#     source .env
# else
#     echo ".env file not found!"
#     exit 1
# fi

# Check if data.txt exists
if [[ ! -f ./data.txt ]]; then
    echo "data.txt not found!"
    exit 1
fi

# Read the content of data.txt
CONTENT=$(cat ./data.txt)

# Prepare the text for the API
TEXT="Start your response with WEEKLY REPORT (Start Month-Start Day-Year to End-Month-End-Day-Year). Summarize this, each line is a different task:\n$CONTENT. Ignore the lunch break, uniform bullet points, no need for titles, avoid duplicates"

# Function to generate the summary
generate_summary() {
  RESPONSE=$(curl -s -H 'Content-Type: application/json' \
    -d '{"contents":[{"parts":[{"text":"'"$TEXT"'"}]}]}' \
    -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$GEMINI_API_KEY")
  echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text'
}

# Initial summary generation
SUMMARY=$(generate_summary)

# Format the summary into bullet points
BULLET_SUMMARY=$(echo "$SUMMARY" | sed 's/^/* /')

# Output the bullet summary
echo -e "Generated Summary:\n$BULLET_SUMMARY"

# Send the summary to the bot
# Construct JSON payload directly with BULLET_SUMMARY
JSON_PAYLOAD=$(jq -n --arg message "$BULLET_SUMMARY" '{text: $message}')

# Send the notification
RESPONSE=$(curl -s -X POST "$WEEKLY_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

echo "Notification sent to bot: $RESPONSE"
