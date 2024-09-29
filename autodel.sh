#!/bin/bash

# Check if data.txt exists
if [[ -f ./data.txt ]]; then
    # Check if data.txt is empty
    if [[ ! -s ./data.txt ]]; then
        echo "data.txt is already empty. No action required."
    else
        # Empty data.txt
        > ./data.txt
        echo "data.txt has been successfully cleared."

        # Notify via Daily Webhook
        RESPONSE=$(curl -s -X POST "$DAILY_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"The data file has been successfully cleared.\"}")

        echo "Notification sent to bot (Daily): $RESPONSE"
    fi
else
    echo "data.txt not found!"
    exit 1
fi
