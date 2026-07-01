#!/bin/bash

set -e

mkdir -p /run/dbus
mkdir -p /var/run/xrdp
mkdir -p /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

rm -f /tmp/.X*-lock

dbus-daemon --system

service xrdp-sesman start
service xrdp start

echo "=============================="
echo "XRDP Started"
echo "Port : 3389"
echo "User : root"
echo "Password : ja908070"
echo "=============================="

tail -F \
/var/log/xrdp.log \
/var/log/xrdp-sesman.log
