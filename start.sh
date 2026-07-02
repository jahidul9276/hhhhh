#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    pkill -x xrdp 2>/dev/null || true
    pkill -x xrdp-sesman 2>/dev/null || true
    pkill -x pulseaudio 2>/dev/null || true
    pkill -x dbus-daemon 2>/dev/null || true
    rm -f /run/dbus/pid
    exit 0
}

trap cleanup SIGTERM SIGINT

# Create directories
mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# Clean up stale files
echo "Cleaning up stale files..."
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp-sesman/xrdp-sesman.pid

# Kill any existing processes
echo "Stopping any existing processes..."
pkill -x dbus-daemon 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
sleep 2

# Start dbus
echo "[1/3] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 1
echo "dbus-daemon started"

# Start sesman
echo "[2/3] Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman --nofork &
sleep 3

# Start xrdp
echo "[3/3] Starting xrdp on port 3389..."
echo "========================================="
echo "XRDP Server is ready!"
echo "Connect to: localhost:3389"
echo "Username: root"
echo "Password: ja908070"
echo "========================================="

exec /usr/sbin/xrdp --nofork
