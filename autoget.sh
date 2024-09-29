#!/bin/bash

# Service account credentials
# if [[ -f .env ]]; then
#     source .env
# else
#     echo ".env file not found!"
#     exit 1
# fi

# Encode the JWT header
JWT_HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 | tr -d '\n=' | tr '/+' '_-')

# Encode the JWT claim set (with 1-hour expiration)
NOW=$(date +%s)
EXP=$(($NOW + 3600))
JWT_CLAIM=$(echo -n "{\"iss\":\"$CLIENT_EMAIL\",\"scope\":\"https://www.googleapis.com/auth/spreadsheets.readonly\",\"aud\":\"https://oauth2.googleapis.com/token\",\"exp\":$EXP,\"iat\":$NOW}" | openssl base64 | tr -d '\n=' | tr '/+' '_-')

# Write the private key to a temporary file
PRIVATE_KEY_FILE=$(mktemp)
echo -e "$PRIVATE_KEY" > "$PRIVATE_KEY_FILE"

# Sign the JWT
SIGNATURE=$(echo -n "$JWT_HEADER.$JWT_CLAIM" | openssl dgst -sha256 -sign "$PRIVATE_KEY_FILE" | openssl base64 | tr -d '\n=' | tr '/+' '_-')

# Clean up the temporary private key file
rm "$PRIVATE_KEY_FILE"

# Assemble the final JWT
JWT="$JWT_HEADER.$JWT_CLAIM.$SIGNATURE"

# Get the access token
ACCESS_TOKEN=$(curl -s --request POST \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$JWT" \
    https://oauth2.googleapis.com/token | jq -r .access_token)

# Fetch data from the Google Sheet
RESPONSE=$(curl -s --request GET \
    "https://sheets.googleapis.com/v4/spreadsheets/$SHEET_ID/values/$RANGE?access_token=$ACCESS_TOKEN")

if [[ $RESPONSE == *"error"* ]]; then
    echo "Error in API response: $RESPONSE"
    exit 1
fi

# Check if values are present
if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    echo "All values in the range:"
    VALUES=$(echo "$RESPONSE" | jq -r '.values[] | .[] // empty')
    echo "$VALUES"
else
    echo "Invalid JSON response."
    exit 1
fi

# Ensure data.txt exists
if [[ ! -f ./data.txt ]]; then
    touch ./data.txt
fi

echo "$(date '+%Y-%m-%d %H:%M:%S')" >> ./data.txt
echo "$VALUES" >> ./data.txt
echo "" >> ./data.txt 
echo "Values saved to data.txt."

TEXT="Summarize the following in concise bullet points: $VALUES. Provide only descriptions—no subject lines, introductions, or text formatting like asterisk, sharp sigh etc."

# Function to generate the summary using Gemini API
generate_summary() {
  RESPONSE=$(curl -s -H 'Content-Type: application/json' \
    -d '{"contents":[{"parts":[{"text":"'"$TEXT"'"}]}]}' \
    -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$GEMINI_API_KEY")
  
  # Extract and return the summary
  echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text'
}

# Initial summary generation
SUMMARY=$(generate_summary)

# Check if the summary is valid
if [[ -z "$SUMMARY" ]]; then
    echo "Failed to generate a summary."
    exit 1
fi

# Output the generated summary
echo -e "Generated Summary:\n$SUMMARY"

# Send the summary to the bot
JSON_PAYLOAD=$(jq -n --arg message "Generated Summary:\\n $SUMMARY" '{text: $message}')

# Send the notification to the webhook
RESPONSE=$(curl -s -X POST "$WEEKLY_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

# Output the response from the webhook
echo "Notification sent to bot: $RESPONSE"