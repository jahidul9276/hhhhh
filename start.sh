#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "Container ID: $(hostname)"
echo "========================================="

# Minimal startup script for XRDP services

# Apply permissive polkit/pam changes if present (safe to reapply)
mkdir -p /etc/polkit-1/localauthority/50-local.d/ 2>/dev/null || true

# Ensure Xauthority exists for the user
if [ -d /home/xrdpuser ]; then
    touch /home/xrdpuser/.Xauthority
    chown xrdpuser:xrdpuser /home/xrdpuser/.Xauthority || true
    chmod 600 /home/xrdpuser/.Xauthority || true
fi

# Clean up stale locks
rm -f /tmp/.X0-lock /tmp/.X10-lock /tmp/.X11-unix/X0 /tmp/.X11-unix/X10 || true

# Start system dbus if available
if command -v dbus-daemon >/dev/null 2>&1; then
    echo "[1/4] Starting dbus-daemon..."
    dbus-daemon --system --fork || true
    sleep 1
fi

# Start pulseaudio if available
if command -v pulseaudio >/dev/null 2>&1; then
    echo "[2/4] Starting pulseaudio..."
    export PULSE_RUNTIME_PATH=/run/pulse
    pulseaudio --start --daemonize --exit-idle-time=-1 --disable-shm=yes --realtime=no 2>/dev/null || true
    sleep 1
fi

# Start xrdp-sesman
echo "[3/4] Starting xrdp-sesman..."
if [ -x /usr/sbin/xrdp-sesman ]; then
    /usr/sbin/xrdp-sesman --nodaemon &
    SESMAN_PID=$!
    sleep 2
fi

# Start xrdp in foreground
echo "[4/4] Starting xrdp..."
if [ -x /usr/sbin/xrdp ]; then
    exec /usr/sbin/xrdp --nodaemon
else
    echo "xrdp binary not found"
    sleep infinity
fi
