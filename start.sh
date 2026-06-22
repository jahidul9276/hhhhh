#!/bin/bash

service dbus start

pulseaudio --start \
--system \
--disallow-exit \
--disable-shm

mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

service xrdp start

echo "GLIBC:"
ldd --version | head -1

echo "Python:"
python3 --version

tail -f /var/log/xrdp-sesman.log
