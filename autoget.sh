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

# Send notification to the bot
if [[ -n "$VALUES" ]]; then
    MESSAGE="Daily report saved with values:\n$VALUES"
else
    MESSAGE="Daily report saved, but no values were retrieved."
fi

# Construct JSON payload
JSON_PAYLOAD=$(jq -n --arg message "$MESSAGE" '{text: $message}')

# Send the notification
RESPONSE=$(curl -s -X POST "$WEEKLY_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

echo "Notification sent to bot: $RESPONSE"