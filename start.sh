#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "Container ID: $(hostname)"
echo "========================================="

# ============================================
# FORCE AUTHENTICATION BYPASS
# ============================================

# Fix PAM - THIS IS THE KEY
cat > /etc/pam.d/xrdp-sesman <<'PAMEOF'
#%PAM-1.0
auth        sufficient    pam_permit.so
auth        required      pam_env.so
account     sufficient    pam_permit.so
session     sufficient    pam_permit.so
PAMEOF

cat > /etc/pam.d/xrdp <<'PAMEOF'
#%PAM-1.0
auth        sufficient    pam_permit.so
auth        required      pam_env.so
account     sufficient    pam_permit.so
session     sufficient    pam_permit.so
PAMEOF

# Force sesman.ini
cat > /etc/xrdp/sesman.ini <<'SESMANEOF'
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=true
UserWindowManager=startwm.sh
DefaultWindowManager=startwm.sh
AllowRootLogin=true
AllowConsoleLogin=true
RootLoginAllowed=true
DisableAuthentication=true
EnableRemoteLogin=true
AlwaysGroupCheck=false
FuseMountName=thinclient_drives
SessionTimeout=0
DisconnectedTimeLimit=0
IdleTimeLimit=0
KillDisconnected=false
XDisplay=10
DisplayOffset=10
MaxDisplayNumber=50
UseXOrg=1
X11rdpPath=/usr/lib/xorg/Xorg

[X11rdp]
param=Xorg
param=-config
param=xrdp/xorg.conf
param=-noreset
param=-nolisten
param=tcp
param=-logfile
param=.xorgxrdp.%s.log

[Chansrv]
FuseMountName=thinclient_drives

[SessionVariables]
X11DisplayOffset=10
MaxDisplayNumber=50
KillDisconnected=false
IdleTimeLimit=0
DisconnectedTimeLimit=0
SESMANEOF

echo "✓ Authentication bypass configured"

# Setup directories
mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /home/xrdpuser/.config/pulse /tmp/.X11-unix /run/user/1000
mkdir -p /tmp/thinclient_drives /var/lib/xrdp /var/log/xrdp
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/1000
chmod 755 /var/run/xrdp /var/run/xrdp-sesman /tmp/thinclient_drives

# Create Xauthority files
touch /root/.Xauthority /home/xrdpuser/.Xauthority 2>/dev/null || true
chmod 600 /root/.Xauthority /home/xrdpuser/.Xauthority 2>/dev/null || true
chown xrdpuser:xrdpuser /home/xrdpuser/.Xauthority 2>/dev/null || true

# Clean up
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock /tmp/.X10-lock
rm -f /tmp/.X11-unix/X0 /tmp/.X11-unix/X10 /tmp/.X11-unix/X11
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp-sesman/xrdp-sesman.pid /run/pulse/pid

# Kill leftover processes
pkill -x dbus-daemon 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
pkill -x Xorg 2>/dev/null || true
sleep 3

# Start dbus
echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 2
echo "✓ dbus-daemon started"

# Start pulseaudio
echo "[2/4] Starting pulseaudio..."
export PULSE_RUNTIME_PATH=/run/pulse
pulseaudio --start --daemonize --exit-idle-time=-1 --disable-shm=yes --realtime=no 2>/dev/null || echo "⚠ Pulseaudio not available"
sleep 2

# Start xrdp-sesman
echo "[3/4] Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!
sleep 5

if ps -p $SESMAN_PID > /dev/null 2>&1; then
    echo "✓ xrdp-sesman started (PID: $SESMAN_PID)"
else
    echo "✗ ERROR: xrdp-sesman failed to start"
    if [ -f /var/log/xrdp-sesman.log ]; then
        tail -30 /var/log/xrdp-sesman.log
    fi
    exit 1
fi

echo ""
echo "========================================="
echo "✓ XRDP Server is ready!"
echo "  Connect to: localhost:3389"
echo ""
echo "  Username: root"
echo "  Password: ja908070"
echo "========================================="

# Start xrdp in foreground
exec /usr/sbin/xrdp --nodaemon
