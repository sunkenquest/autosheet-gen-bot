#!/bin/bash

# Ensure the API key is set
if [[ -f .env ]]; then
    source .env
else
    echo ".env file not found!"
    exit 1
fi

# Check if data.txt exists
if [[ ! -f data.txt ]]; then
    echo "data.txt not found!"
    exit 1
fi

# Read the content of data.txt
CONTENT=$(cat data.txt)

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

# Output the summary and ask for confirmation
while true; do
    echo -e "Generated Summary:\n$SUMMARY"
    read -p "Is this summary correct? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
        # Save to result.txt
        echo "$SUMMARY" > result.txt
        echo "Summary saved to result.txt."
        break
    elif [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
        # Regenerate summary
        echo "Regenerating summary..."
        SUMMARY=$(generate_summary)
    else
        echo "Please enter 'y' for yes or 'n' for no."
    fi
done
