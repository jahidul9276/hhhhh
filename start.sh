#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Create runtime directories
mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /root/.config/pulse /tmp/.X11-unix /run/user/0 /tmp/thinclient_drives
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/0
chmod 755 /tmp/thinclient_drives

# Create Xauthority
touch /root/.Xauthority && chmod 600 /root/.Xauthority

# Clean up stale files
echo "Cleaning up stale files..."
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp-sesman/xrdp-sesman.pid /run/pulse/pid

# Kill leftover processes
echo "Cleaning up processes..."
pkill -x dbus-daemon 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
sleep 2

# Mount proc/sys for FUSE
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sys /sys 2>/dev/null || true

# Start dbus
echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 1
echo "✓ dbus-daemon started"

# Start pulseaudio
echo "[2/4] Starting pulseaudio..."
export PULSE_RUNTIME_PATH=/run/pulse
pulseaudio --start --daemonize --exit-idle-time=-1 2>/dev/null || true
sleep 1
echo "✓ pulseaudio configured"

# Start xrdp-sesman
echo "[3/4] Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman --nodaemon &
sleep 3
echo "✓ xrdp-sesman started"

# Start xrdp
echo "[4/4] Starting xrdp on port 3389..."
echo "========================================="
echo "✓ XRDP Server is ready!"
echo "  Connect to: localhost:3389"
echo "  Username: root"
echo "  Password: ja908070"
echo "========================================="

exec /usr/sbin/xrdp --nodaemon
