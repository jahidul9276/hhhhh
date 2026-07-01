#!/bin/bash
set -e

mkdir -p /run/dbus
mkdir -p /var/run/xrdp
mkdir -p /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

rm -f /run/dbus/pid
rm -f /tmp/.X*-lock

dbus-daemon --system --fork || true

service xrdp-sesman start
service xrdp start

echo "XRDP started"

tail -F /var/log/xrdp.log /var/log/xrdp-sesman.log
