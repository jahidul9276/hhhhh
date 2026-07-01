#!/bin/bash

# Fix for xrdp-sesman service
echo "Starting XRDP services..."

# Start dbus if not running
if ! pgrep -x "dbus-daemon" > /dev/null; then
    echo "Starting dbus-daemon..."
    dbus-daemon --system --fork
fi

# Start pulseaudio if not running
if ! pgrep -x "pulseaudio" > /dev/null; then
    echo "Starting pulseaudio..."
    pulseaudio --start --daemonize
fi

# Start xrdp-sesman directly (since systemd might not work in container)
echo "Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman --nodaemon &

# Wait a bit for sesman to start
sleep 2

# Start xrdp
echo "Starting xrdp..."
/usr/sbin/xrdp --nodaemon

# Keep container running if xrdp fails
while true; do
    sleep 60
done
