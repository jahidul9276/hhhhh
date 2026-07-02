#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Create directories
mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /root/.config/pulse /tmp/.X11-unix /run/user/0
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/0

# Clean up
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp-sesman/xrdp-sesman.pid /run/pulse/pid
rm -f /tmp/.X11-unix/X0 /tmp/.X11-unix/X10

# Kill processes
pkill -x dbus-daemon 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
pkill -x Xorg 2>/dev/null || true
sleep 3

# Start dbus
dbus-daemon --system --fork
sleep 2

# Start pulseaudio
pulseaudio --start --daemonize --exit-idle-time=-1 2>/dev/null || true
sleep 2

# Start xrdp-sesman
/usr/sbin/xrdp-sesman --nodaemon &
sleep 5

# Start xrdp
/usr/sbin/xrdp --nodaemon &
sleep 3

echo "========================================="
echo "✓ XRDP Server is ready!"
echo "  Connect to: localhost:3389"
echo "  Username: root"
echo "  Password: ja908070"
echo "========================================="

# Start Hermes if available
if command -v hermes &> /dev/null; then
    echo "Starting Hermes gateway..."
    hermes gateway run &
fi

# Keep container running
wait
