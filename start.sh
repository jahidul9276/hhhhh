#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "Container ID: $(hostname)"
echo "========================================="

# ============================================
# Re-apply runtime configuration
# (container restarts / volumes can reset these)
# ============================================
echo "=== Applying runtime configuration ==="

# polkit: allow local X sessions to manage themselves without a prompt
mkdir -p /etc/polkit-1/localauthority/50-local.d
rm -f /etc/polkit-1/localauthority/50-local.d/*.pkla 2>/dev/null || true
rm -f /etc/polkit-1/localauthority/10-vendor.d/*.pkla 2>/dev/null || true
cat > /etc/polkit-1/localauthority/50-local.d/99-xrdp.pkla <<'POLKITEOF'
[Allow xrdp]
Identity=unix-user:*
Action=*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
POLKITEOF

# sesman.ini
# IMPORTANT: root-login control (AllowRootLogin) only works inside the
# [Security] section. xrdp-sesman silently ignores any parameter placed
# in the wrong section, which is what caused "User is not authorized".
# `DisableAuthentication` and `RootLoginAllowed` are NOT real xrdp-sesman
# parameters and have been removed.
cat > /etc/xrdp/sesman.ini <<'SESMANEOF'
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=true
UserWindowManager=startwm.sh
DefaultWindowManager=startwm.sh
ReconnectSh=reconnectwm.sh

[Security]
AllowRootLogin=true
MaxLoginRetry=4
TerminalServerUsers=tsusers
TerminalServerAdmins=tsadmins
AlwaysGroupCheck=false

[Sessions]
X11DisplayOffset=10
MaxDisplayNumber=50
KillDisconnected=false
DisconnectedTimeLimit=0
IdleTimeLimit=0
Policy=Default

[Logging]
LogFile=xrdp-sesman.log
LogLevel=DEBUG
EnableSyslog=true

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
KillDisconnected=false
IdleTimeLimit=0
DisconnectedTimeLimit=0
SESMANEOF

# xrdp.ini
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

echo "✓ Configuration applied"

# ============================================
# Filesystem / namespace setup
# ============================================
echo "Setting up mount namespace permissions..."

mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /home/xrdpuser/.config/pulse /root/.config/pulse
mkdir -p /tmp/.X11-unix /run/user/1000 /run/user/0
mkdir -p /tmp/thinclient_drives /var/lib/xrdp /var/log/xrdp
mkdir -p /proc /sys /dev /dev/shm
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/1000 /run/user/0
chmod 755 /var/run/xrdp /var/run/xrdp-sesman /tmp/thinclient_drives
chown xrdpuser:xrdpuser /run/user/1000 /home/xrdpuser/.config/pulse 2>/dev/null || true

if ! mountpoint -q /proc; then mount -t proc proc /proc 2>/dev/null || true; fi
if ! mountpoint -q /sys; then mount -t sysfs sys /sys 2>/dev/null || true; fi
if ! mountpoint -q /dev; then mount -t devtmpfs dev /dev 2>/dev/null || true; fi
if ! mountpoint -q /dev/shm; then mount -t tmpfs tmpfs /dev/shm 2>/dev/null || true; fi
if ! mountpoint -q /dev/pts; then mount -t devpts devpts /dev/pts 2>/dev/null || true; fi

[ -e /dev/tty ]  || mknod -m 666 /dev/tty  c 5 0 2>/dev/null || true
[ -e /dev/null ] || mknod -m 666 /dev/null c 1 3 2>/dev/null || true
[ -e /dev/zero ] || mknod -m 666 /dev/zero c 1 5 2>/dev/null || true

# Xauthority for both users
touch /root/.Xauthority /home/xrdpuser/.Xauthority
chmod 600 /root/.Xauthority /home/xrdpuser/.Xauthority
chown xrdpuser:xrdpuser /home/xrdpuser/.Xauthority

# ============================================
# Cleanup stale files / processes from a previous run
# ============================================
echo "Cleaning up stale files..."
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock /tmp/.X10-lock
rm -f /tmp/.X11-unix/X0 /tmp/.X11-unix/X10 /tmp/.X11-unix/X11
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp-sesman/xrdp-sesman.pid /run/pulse/pid

echo "Cleaning up processes..."
pkill -x dbus-daemon     2>/dev/null || true
pkill -x pulseaudio      2>/dev/null || true
pkill -x xrdp-sesman     2>/dev/null || true
pkill -x xrdp            2>/dev/null || true
pkill -x Xorg            2>/dev/null || true
pkill -x startxfce4      2>/dev/null || true
pkill -x xfce4-session   2>/dev/null || true
sleep 2

# ============================================
# Start services
# ============================================
echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 2
echo "✓ dbus-daemon started"

echo "[2/4] Starting pulseaudio..."
export PULSE_RUNTIME_PATH=/run/pulse
pulseaudio --start --daemonize --exit-idle-time=-1 --disable-shm=yes --realtime=no 2>/dev/null || echo "⚠ Pulseaudio not available"
sleep 1
echo "✓ pulseaudio configured"

echo "[3/4] Starting xrdp-sesman..."
echo "----------------------------------------"
grep -A6 '^\[Security\]' /etc/xrdp/sesman.ini
echo "----------------------------------------"

/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!
sleep 4

if ps -p $SESMAN_PID > /dev/null 2>&1; then
    echo "✓ xrdp-sesman started (PID: $SESMAN_PID)"
else
    echo "✗ ERROR: xrdp-sesman failed to start"
    [ -f /var/log/xrdp-sesman.log ] && tail -30 /var/log/xrdp-sesman.log
    exit 1
fi

echo "[4/4] Starting xrdp on port 3389..."
echo ""
echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  Memory: $(free -h | awk '/Mem:/{print $2}')"
echo "  CPU: $(nproc) cores"
echo ""
echo "========================================="
echo "✓ XRDP Server is ready! Connect to localhost:3389"
echo ""
echo "  Username: xrdpuser   Password: ja908070   (recommended)"
echo "  Username: root       Password: ja908070   (now permitted via [Security])"
echo "========================================="
echo ""
echo "Live logs:"
echo "  docker exec -it xrdp tail -f /var/log/xrdp.log"
echo "  docker exec -it xrdp tail -f /var/log/xrdp-sesman.log"
echo ""

exec /usr/sbin/xrdp --nodaemon
