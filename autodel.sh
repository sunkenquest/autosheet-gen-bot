#!/bin/bash

# Empty data.txt
if [[ -f ./data.txt ]]; then
    > data.txt
    echo "data.txt emptied."
else
    echo "data.txt not found!"
    exit 1
fi

echo "empty na :>"

# Notify via Daily Webhook
RESPONSE=$(curl -s -X POST "$DAILY_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"pool emptied :>.\"}")

echo "Notification sent to bot (Daily): $RESPONSE"
