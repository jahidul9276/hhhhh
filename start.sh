#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Create runtime directories
mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /root/.config/pulse /tmp/.X11-unix /run/user/0
mkdir -p /tmp/thinclient_drives
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/0
chmod 755 /tmp/thinclient_drives

# Create Xauthority if missing
touch /root/.Xauthority && chmod 600 /root/.Xauthority

# Clean up all stale files
echo "Cleaning up stale files..."
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp-sesman/xrdp-sesman.pid /run/pulse/pid
rm -f /tmp/.X11-unix/X0 /tmp/.X11-unix/X10 /tmp/.X11-unix/X11

# Kill all leftover processes
echo "Cleaning up processes..."
pkill -x dbus-daemon 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
pkill -x Xorg 2>/dev/null || true
pkill -x startxfce4 2>/dev/null || true
pkill -x xfce4-session 2>/dev/null || true
sleep 3

# Start dbus
echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 2
echo "✓ dbus-daemon started"

# Start pulseaudio
echo "[2/4] Starting pulseaudio..."
export PULSE_RUNTIME_PATH=/run/pulse
pulseaudio --start --daemonize --exit-idle-time=-1 2>/dev/null || echo "⚠ Pulseaudio not available"
sleep 2
echo "✓ pulseaudio configured"

# Start xrdp-sesman with proper configuration
echo "[3/4] Starting xrdp-sesman..."
# Ensure sesman.ini has correct settings
if [ -f /etc/xrdp/sesman.ini ]; then
    sed -i 's/^#.*SessionVariables=.*/SessionVariables=XDG_CURRENT_DESKTOP=XFCE,XDG_MENU_PREFIX=xfce-,XDG_CONFIG_DIRS=\/etc\/xdg\/xfce4:\/etc\/xdg,XDG_DATA_DIRS=\/usr\/share\/xfce4:\/usr\/share/g' /etc/xrdp/sesman.ini 2>/dev/null || true
fi

/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!
sleep 5

if ps -p $SESMAN_PID > /dev/null 2>&1; then
    echo "✓ xrdp-sesman started (PID: $SESMAN_PID)"
else
    echo "✗ ERROR: xrdp-sesman failed to start"
    exit 1
fi

# Start xrdp
echo "[4/4] Starting xrdp on port 3389..."
echo "========================================="
echo "✓ XRDP Server is ready!"
echo "  Connect to: localhost:3389"
echo "  Username: root"
echo "  Password: ja908070"
echo "========================================="

# Show session info
echo ""
echo "Session Information:"
echo "  Display: :10"
echo "  Xauthority: /root/.Xauthority"
echo "  Runtime dir: /run/user/0"
echo ""

exec /usr/sbin/xrdp --nodaemon
