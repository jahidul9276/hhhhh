#!/bin/bash

set -e

mkdir -p /run/dbus
dbus-daemon --system

mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

pulseaudio --system --disallow-exit --disable-shm &

service xrdp start

echo "GLIBC:"
ldd --version | head -1

echo "Python:"
python3 --version

tail -f /var/log/xrdp-sesman.log
