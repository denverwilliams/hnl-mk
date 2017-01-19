#!/bin/bash
[ -d tmp/cmd-channels ] || mkdir tmp/cmd-channels
[ -e tmp/cmd-channels/node-state-channel ] || mkfifo tmp/cmd-channels/node-state-channel
while read msg < tmp/cmd-channels/node-state-channel; do
    if [ "$msg" = "reboot" ]; then
        echo reboot
    elif [ "$msg" = "poweroff" ]; then
        echo poweroff
    else
        echo "message '$msg' unrecognized"
    fi
done
