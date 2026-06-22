#!/bin/bash

service dbus start


pulseaudio \
--start \
--system \
--disallow-exit \
--disable-shm


mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix


service xrdp start


echo "===================="
echo "XRDP READY"
echo "Python:"
python3 --version
echo "===================="


tail -f /var/log/xrdp-sesman.log
