#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Create runtime directories with proper permissions
mkdir -p /run/dbus /var/run/dbus /run/pulse
mkdir -p /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /root/.config/pulse /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
chmod 755 /run/pulse

# Clean up stale files
echo "Cleaning up stale files..."
rm -f /run/dbus/pid /var/run/dbus/pid
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
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

# Start D-Bus
echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 2

if pgrep -x "dbus-daemon" > /dev/null; then
    echo "✓ dbus-daemon started (PID: $(pgrep -x dbus-daemon))"
else
    echo "⚠ WARNING: dbus-daemon failed to start"
fi

# Start PulseAudio
echo "[2/4] Starting pulseaudio..."
if ! pgrep -x "pulseaudio" > /dev/null; then
    export PULSE_RUNTIME_PATH=/run/pulse
    pulseaudio --start --daemonize --exit-idle-time=-1 -vvvv 2>&1 | tee /var/log/pulse.log || true
    sleep 2
    if pgrep -x "pulseaudio" > /dev/null; then
        echo "✓ pulseaudio started (PID: $(pgrep -x pulseaudio))"
    else
        echo "⚠ WARNING: pulseaudio failed to start"
        echo "   Check /var/log/pulse.log for details"
        # Create dummy socket to prevent errors
        touch /run/pulse/native
    fi
else
    echo "✓ pulseaudio already running"
fi

# Start XRDP session manager
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

# Start XRDP
echo "[4/4] Starting xrdp on port 3389..."
echo "========================================="
echo "✓ XRDP Server is ready!"
echo "========================================="
echo "  Connect to: localhost:3389"
echo "  Username:   root"
echo "  Password:   ja908070"
echo "========================================="

exec /usr/sbin/xrdp --nodaemon
