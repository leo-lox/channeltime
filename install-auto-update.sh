#!/bin/bash




nohup ./update.sh > auto-update.log 2>&1 &
echo $! > auto_update_pid.txt

