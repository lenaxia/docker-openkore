#!/bin/bash

# Run OpenKore and capture its output
perl /opt/openkore/openkore.pl "$@" |
while read -r line; do
    echo "$line"
    # Check if the line matches the desired condition
    if [[ "$line" == *"Please enter your Ragnarok Online username."* ]]; then
        # Kill the OpenKore process
        pkill -f openkore.pl
        exit 0
    fi
done
