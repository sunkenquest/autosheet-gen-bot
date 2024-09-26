#!/bin/bash

if [[ -f data.txt ]]; then
    > data.txt
else
    echo "data.txt not found!"
    exit 1
fi


if [[ -f result.txt ]]; then
    > result.txt
else
    echo "result.txt not found!"
    exit 1
fi

echo "empty na :>"
