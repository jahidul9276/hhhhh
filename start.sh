#!/bin/bash

set -e

mkdir -p /run/dbus
dbus-daemon --system

mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

pulseaudio --system --disallow-exit --disable-shm &

service xrdp start

echo "======================"
echo "GLIBC:"
ldd --version | head -1

echo "Python:"
python3 --version

echo "XRDP running on port 3389"
echo "======================"

tail -F /var/log/xrdp.log /var/log/xrdp-sesman.log
