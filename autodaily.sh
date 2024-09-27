#!/bin/bash

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
    if [[ $(echo "$RESPONSE" | jq '.values') == "null" || $(echo "$RESPONSE" | jq '.values | length') -eq 0 ]]; then
        # Send the message to the bot if values are empty or null
        RESPONSE=$(curl -s -X POST "$DAILY_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d '{"text": "Wala man laman daily mo"}')
        
        # Check if the message was sent successfully
        if [[ $? -eq 0 ]]; then
            echo "Message sent to the bot successfully."
        else
            echo "Failed to send the message."
        fi
    else
        # If values are present
        echo "All values in the range:"
        VALUES=$(echo "$RESPONSE" | jq -r '.values[] | .[] // empty')
        echo "$VALUES"

        # Use Gemini to summarize the response
        TEXT="Summarize the following in concise bullet points: $VALUES. Provide only descriptions—no subject lines, introductions, or text formatting like asterisk, sharp sigh etc."
        SUMMARY_RESPONSE=$(curl -s -H 'Content-Type: application/json' \
            -d '{"contents":[{"parts":[{"text":"'"$TEXT"'"}]}]}' \
            -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$GEMINI_API_KEY")
        
        # Extract summary text
        SUMMARY=$(echo "$SUMMARY_RESPONSE" | jq -r '.candidates[0].content.parts[0].text')
        
        echo "Summary:"
        echo "$SUMMARY"

        # Prepare JSON payload for the webhook
        JSON_PAYLOAD=$(jq -n --arg text "$SUMMARY" '{text: $text}')

        # Send the JSON payload to the webhook
        RESPONSE=$(curl -s -X POST "$DAILY_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD")

        # Check if the message was sent successfully
        if [[ $? -eq 0 ]]; then
            echo "Message sent to the channel successfully."
        else
            echo "Failed to send the message."
        fi
    fi
else
    echo "Invalid JSON response."
    exit 1
fi
