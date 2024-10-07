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

# Check for an error in the response
if [[ $(echo "$RESPONSE" | jq -r .error) != "null" ]]; then
    echo "Error in API response: $RESPONSE"
    exit 1
fi

# Check if values are present
VALUES=$(echo "$RESPONSE" | jq -r .values)

if [[ "$VALUES" == "null" || -z "$VALUES" ]]; then
    echo "No values found in the specified range."
    exit 1
else
    echo "Generated Summary:"
    
    # Flatten the nested array and format as bullet points
    BULLET_POINTS=$(echo "$VALUES" | jq -r '.[] | .[]' | sed '/^\s*$/d' | sed 's/^/- /')

    echo "$BULLET_POINTS" # Print the bullet points for confirmation
fi

# Ensure data.txt exists
if [[ ! -f ./data.txt ]]; then
    touch ./data.txt
fi

echo "$(date '+%Y-%m-%d %H:%M:%S')" >> ./data.txt
echo "$BULLET_POINTS" >> ./data.txt
echo "" >> ./data.txt 
echo "Values saved to data.txt."

# Prepare the message with proper newlines
MESSAGE=$(printf "Generated Summary:\n%s" "$BULLET_POINTS")

# Construct JSON payload with the formatted message
JSON_PAYLOAD=$(jq -n --arg message "$MESSAGE" '{text: $message}')

# Send the notification to the webhook
RESPONSE=$(curl -s -X POST "$DAILY_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

# Output the response from the webhook
echo "Notification sent to bot: $RESPONSE"
