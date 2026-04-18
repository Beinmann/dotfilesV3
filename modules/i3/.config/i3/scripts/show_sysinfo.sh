#!/bin/bash
cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
ram=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
disk=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')
uptime=$(uptime -p | sed 's/^up //')

notify-send "System Info" "CPU:    ${cpu}%
RAM:    ${ram}
Disk:   ${disk}
Uptime: ${uptime}"
