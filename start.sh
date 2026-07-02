#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Create runtime directories if they don't exist
mkdir -p /run/dbus
mkdir -p /var/run/dbus
mkdir -p /run/pulse
mkdir -p /var/run/xrdp
mkdir -p /var/run/xrdp-sesman
mkdir -p /root/.config/pulse

# Clean up any stale lock files
rm -f /tmp/.X0-lock
rm -f /var/run/xrdp/xrdp.pid
rm -f /var/run/xrdp-sesman/xrdp-sesman.pid
rm -f /run/pulse/pid

# Start dbus (required for xrdp)
echo "[1/4] Starting dbus-daemon..."
if ! pgrep -x "dbus-daemon" > /dev/null; then
    dbus-daemon --system --fork --print-address 2>/dev/null || true
    sleep 1
    echo "dbus-daemon started successfully"
else
    echo "dbus-daemon already running"
fi

# Start pulseaudio
echo "[2/4] Starting pulseaudio..."
if ! pgrep -x "pulseaudio" > /dev/null; then
    # Create pulse cookie
    pulseaudio --start --daemonize 2>/dev/null || true
    sleep 1
    
    # Check if pulseaudio started
    if pgrep -x "pulseaudio" > /dev/null; then
        echo "pulseaudio started successfully"
    else
        echo "WARNING: pulseaudio failed to start, continuing anyway"
    fi
else
    echo "pulseaudio already running"
fi

# Start xrdp-sesman
echo "[3/4] Starting xrdp-sesman..."
if pgrep -x "xrdp-sesman" > /dev/null; then
    echo "xrdp-sesman already running, killing old instance..."
    pkill -x xrdp-sesman || true
    sleep 1
fi

/usr/sbin/xrdp-sesman --nofork &

# Give sesman time to initialize
sleep 3
echo "xrdp-sesman started successfully"

# Start xrdp
echo "[4/4] Starting xrdp on port 3389..."
if pgrep -x "xrdp" > /dev/null; then
    echo "xrdp already running, killing old instance..."
    pkill -x xrdp || true
    sleep 1
fi

echo "========================================="
echo "XRDP Server is ready!"
echo "Connect to: localhost:3389"
echo "Username: root"
echo "Password: ja908070"
echo "========================================="

exec /usr/sbin/xrdp --nofork
