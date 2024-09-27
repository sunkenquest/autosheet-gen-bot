#!/bin/bash

# Empty data.txt
if [[ -f ./data.txt ]]; then
    > data.txt
    echo "data.txt emptied."
else
    echo "data.txt not found!"
    exit 1
fi

# Empty result.txt
if [[ -f ./result.txt ]]; then
    > result.txt
    echo "result.txt emptied."
else
    echo "result.txt not found!"
    exit 1
fi

echo "empty na :>"

# Notify via Weekly Webhook
RESPONSE=$(curl -s -X POST "$WEEKLY_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"The file data.txt has been successfully emptied.\"}")

echo "Notification sent to bot (Weekly): $RESPONSE"

# Notify via Daily Webhook
RESPONSE=$(curl -s -X POST "$DAILY_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"The file result.txt has been successfully emptied.\"}")

echo "Notification sent to bot (Daily): $RESPONSE"
