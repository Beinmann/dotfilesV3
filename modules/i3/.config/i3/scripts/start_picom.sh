#!/bin/bash
if systemd-detect-virt -q; then
    picom --backend xrender
else
    picom --backend glx
fi
