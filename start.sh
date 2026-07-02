#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "Container ID: $(hostname)"
echo "========================================="

# ============================================
# COMPLETE AUTHORIZATION BYPASS
# ============================================
echo "=== COMPLETE AUTHORIZATION BYPASS ==="

# Ensure directories exist
mkdir -p /etc/xrdp
mkdir -p /etc/polkit-1/localauthority/50-local.d/
mkdir -p /etc/pam.d

# Remove ALL security policies
rm -f /etc/polkit-1/localauthority/50-local.d/*.pkla 2>/dev/null || true
rm -f /etc/polkit-1/localauthority/10-vendor.d/*.pkla 2>/dev/null || true

# Create new policy allowing everything
cat > /etc/polkit-1/localauthority/50-local.d/99-xrdp.pkla <<'POLKITEOF'
[Allow xrdp]
Identity=unix-user:*
Action=*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
POLKITEOF

# CRITICAL: Set up PAM to allow ALL users without authentication
cat > /etc/pam.d/xrdp-sesman <<'PAMEOF'
#%PAM-1.0
auth        required      pam_permit.so
auth        required      pam_env.so
account     required      pam_permit.so
session     required      pam_permit.so
session     optional      pam_motd.so
session     optional      pam_mail.so
PAMEOF

cat > /etc/pam.d/xrdp <<'PAMEOF'
#%PAM-1.0
auth        required      pam_permit.so
auth        required      pam_env.so
account     required      pam_permit.so
session     required      pam_permit.so
PAMEOF

# Force sesman settings with DisableAuthentication=true
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

# Force xrdp settings with root access
cat > /etc/xrdp/xrdp.ini <<'XRDPEOF'
[Globals]
ini_version=1
fork=true
port=3389
use_vsock=false
tcp_nodelay=true
tcp_keepalive=true
security_layer=negotiate
crypt_level=high
max_bpp=32
xserverbpp=32
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
tls_min_version=1.2
tls_max_version=1.3

[Xorg]
name=Xorg
lib=libxup.so
username=root
password=ja908070
ip=127.0.0.1
port=-1
xserverbpp=32
codecs=
security_layer=negotiate
crypt_level=high
max_bpp=32

[X11rdp]
name=X11rdp
lib=libxup.so
username=root
password=ja908070
ip=127.0.0.1
port=-1
xserverbpp=32
codecs=
security_layer=negotiate
crypt_level=high
max_bpp=32

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

echo "✓ All configurations bypassed"

# Setup directories with proper permissions
echo "Setting up directories..."
mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /home/xrdpuser/.config/pulse /tmp/.X11-unix /run/user/1000 /run/user/0
mkdir -p /tmp/thinclient_drives /var/lib/xrdp /var/log/xrdp
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/1000 /run/user/0 2>/dev/null || true
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
echo "Verifying sesman configuration:"
echo "----------------------------------------"
grep -E "AllowRootLogin|RootLoginAllowed|DisableAuthentication" /etc/xrdp/sesman.ini
echo "----------------------------------------"

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
echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  CPU: $(nproc) cores"
echo ""

echo "[5/5] XRDP Server ready!"
echo "========================================="
echo "✓ XRDP Server is ready!"
echo "  Connect to: localhost:3389"
echo ""
echo "  OPTION 1 - Login with root user:"
echo "  Username: root"
echo "  Password: ja908070"
echo ""
echo "  OPTION 2 - Login with non-root user:"
echo "  Username: xrdpuser"
echo "  Password: ja908070"
echo "========================================="
echo ""
echo "AUTHORIZATION STATUS:"
echo "  AllowRootLogin: $(grep ^AllowRootLogin /etc/xrdp/sesman.ini | tail -1)"
echo "  RootLoginAllowed: $(grep ^RootLoginAllowed /etc/xrdp/sesman.ini | tail -1)"
echo "  DisableAuthentication: $(grep ^DisableAuthentication /etc/xrdp/sesman.ini | tail -1)"
echo "  allow_root: $(grep ^allow_root /etc/xrdp/xrdp.ini | tail -1)"
echo "========================================="
echo ""
echo "Session Information:"
echo "  Display: :10"
echo "  Xauthority: /home/xrdpuser/.Xauthority"
echo "  Runtime dir: /run/user/1000"
echo "  Pulse socket: /run/pulse/native"
echo "  DBus socket: /run/dbus/system_bus_socket"
echo "  SSL Certificate: /etc/xrdp/xrdp-cert.pem"
echo ""
echo "To monitor logs:"
echo "  docker exec -it xrdp tail -f /var/log/xrdp.log"
echo "  docker exec -it xrdp tail -f /var/log/xrdp-sesman.log"
echo ""

# Keep the container running with xrdp in foreground
exec /usr/sbin/xrdp --nodaemon
