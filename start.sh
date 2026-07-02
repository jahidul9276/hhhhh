#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "Container ID: $(hostname)"
echo "========================================="

# ============================================
# THE REAL AUTHENTICATION BYPASS
# ============================================

# 1. Backup original files
cp /etc/xrdp/sesman.ini /etc/xrdp/sesman.ini.bak 2>/dev/null || true
cp /etc/pam.d/xrdp-sesman /etc/pam.d/xrdp-sesman.bak 2>/dev/null || true

# 2. FIX PAM - use pam_permit.so (this is the KEY)
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

# 3. Create sesman.ini with ALL settings
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

# 4. Create xrdp.ini
cat > /etc/xrdp/xrdp.ini <<'XRDPEOF'
[Globals]
ini_version=1
fork=true
port=3389
use_vsock=false
tcp_nodelay=true
tcp_keepalive=true
security_layer=negotiate
crypt_level=low
max_bpp=16
xserverbpp=16
codecs=
allow_root=true
allow_console=true
enable_token_login=false
disable_root_login=false
rdp_ssl=yes
ssl_cert_file=/etc/xrdp/xrdp-cert.pem
ssl_key_file=/etc/xrdp/xrdp-key.pem
ssl_verify=no
rdp_use_ssl=yes
crypto_use_fips=false
tcp_send_buffer_bytes=262144
tcp_recv_buffer_bytes=262144
max_connections=100
rdp_enhanced_security=yes
tls_min_version=1.0
tls_max_version=1.3

[Xorg]
name=Xorg
lib=libxup.so
username=root
password=ja908070
ip=127.0.0.1
port=-1
xserverbpp=16
codecs=
security_layer=negotiate
crypt_level=low
max_bpp=16

[X11rdp]
name=X11rdp
lib=libxup.so
username=root
password=ja908070
ip=127.0.0.1
port=-1
xserverbpp=16
codecs=
security_layer=negotiate
crypt_level=low
max_bpp=16

[Chansrv]
name=Chansrv
lib=libchansrv.so
username=root
password=ja908070
ip=127.0.0.1
port=-1

[SessionVariables]
X11DisplayOffset=10
MaxDisplayNumber=50
KillDisconnected=false
IdleTimeLimit=0
DisconnectedTimeLimit=0
XRDPEOF

echo "✓ Configuration files updated"

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

# Clean up stale files
echo "Cleaning up stale files..."
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock /tmp/.X10-lock
rm -f /tmp/.X11-unix/X0 /tmp/.X11-unix/X10 /tmp/.X11-unix/X11
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp-sesman/xrdp-sesman.pid /run/pulse/pid

# Kill leftover processes
echo "Cleaning up processes..."
pkill -x dbus-daemon 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
pkill -x Xorg 2>/dev/null || true
sleep 3

# Start dbus
echo "[1/5] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 2
echo "✓ dbus-daemon started"

# Start pulseaudio
echo "[2/5] Starting pulseaudio..."
export PULSE_RUNTIME_PATH=/run/pulse
pulseaudio --start --daemonize --exit-idle-time=-1 --disable-shm=yes --realtime=no 2>/dev/null || echo "⚠ Pulseaudio not available"
sleep 2

# Start xrdp-sesman
echo "[3/5] Starting xrdp-sesman..."
echo "========================================="
echo "SESMAN CONFIGURATION:"
grep -E "AllowRootLogin|RootLoginAllowed|DisableAuthentication" /etc/xrdp/sesman.ini
echo "========================================="
echo "PAM CONFIGURATION:"
head -5 /etc/pam.d/xrdp-sesman
echo "========================================="

# Start sesman
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

# Start xrdp
echo "[4/5] Starting xrdp on port 3389..."

echo ""
echo "========================================="
echo "✓ XRDP Server is ready!"
echo "  Connect to: localhost:3389"
echo ""
echo "  Username: root"
echo "  Password: ja908070"
echo "========================================="
echo ""
echo "To monitor logs:"
echo "  docker exec -it xrdp tail -f /var/log/xrdp.log"
echo "  docker exec -it xrdp tail -f /var/log/xrdp-sesman.log"
echo ""

# Keep the container running with xrdp in foreground
exec /usr/sbin/xrdp --nodaemon
