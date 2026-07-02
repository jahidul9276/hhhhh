#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Create runtime directories
mkdir -p /run/dbus
mkdir -p /var/run/dbus
mkdir -p /run/pulse
mkdir -p /var/run/xrdp
mkdir -p /var/run/xrdp-sesman
mkdir -p /root/.config/pulse
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# Clean up stale PID files
echo "Cleaning up stale PID files..."
rm -f /run/dbus/pid
rm -f /var/run/dbus/pid
rm -f /tmp/.X0-lock
rm -f /var/run/xrdp/xrdp.pid
rm -f /var/run/xrdp-sesman/xrdp-sesman.pid
rm -f /run/pulse/pid

# Kill any leftover processes
echo "Cleaning up leftover processes..."
pkill -x dbus-daemon 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
sleep 2

# Start dbus
echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 1

if pgrep -x "dbus-daemon" > /dev/null; then
    echo "✓ dbus-daemon started (PID: $(pgrep -x dbus-daemon))"
else
    echo "✗ ERROR: dbus-daemon failed to start"
    exit 1
fi

# Start pulseaudio
echo "[2/4] Starting pulseaudio..."
if ! pgrep -x "pulseaudio" > /dev/null; then
    pulseaudio --start --daemonize 2>/dev/null || echo "⚠ Pulseaudio start failed, continuing..."
    sleep 1
    if pgrep -x "pulseaudio" > /dev/null; then
        echo "✓ pulseaudio started (PID: $(pgrep -x pulseaudio))"
    else
        echo "⚠ pulseaudio not running (continuing anyway)"
    fi
else
    echo "✓ pulseaudio already running"
fi

# Start xrdp-sesman with correct option: --nodaemon
echo "[3/4] Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!
sleep 3

if ps -p $SESMAN_PID > /dev/null 2>&1; then
    echo "✓ xrdp-sesman started (PID: $SESMAN_PID)"
else
    echo "✗ ERROR: xrdp-sesman failed to start"
    exit 1
fi

# Start xrdp with correct option: --nodaemon
echo "[4/4] Starting xrdp on port 3389..."
echo "========================================="
echo "✓ XRDP Server is ready!"
echo "========================================="
echo "  Connect to: localhost:3389"
echo "  Username:   root"
echo "  Password:   ja908070"
echo "========================================="

exec /usr/sbin/xrdp --nodaemon
