FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Add i386 architecture for 32-bit support
RUN dpkg --add-architecture i386

# Install all required packages
RUN apt-get update && apt-get install -y \
xrdp \
xfce4 \
xfce4-goodies \
xorgxrdp \
dbus-x11 \
sudo \
curl \
wget \
nano \
net-tools \
polkitd \
pulseaudio \
pulseaudio-utils \
firefox-esr \
python3 \
python3-pip \
python3-venv \
build-essential \
ca-certificates \
wine \
wine32 \
libc6:i386 \
procps \
iproute2 \
x11-utils \
xauth \
pm-utils \
xserver-xorg-video-dummy \
xserver-xorg-core \
x11-xserver-utils \
xorg \
xvfb \
x11vnc \
openssh-server \
net-tools \
dnsutils \
iputils-ping \
telnet \
ltrace \
strace \
openssl \
certificates \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Set root password
RUN echo "root:ja908070" | chpasswd

# Create necessary directories with proper permissions
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/pulse /var/lib/xrdp /run/user/0 /tmp/.X11-unix /var/log/xrdp
RUN chmod 1777 /tmp/.X11-unix
RUN chmod 700 /run/user/0
RUN chmod 755 /var/run/xrdp /var/run/xrdp-sesman

# Create Xauthority file
RUN touch /root/.Xauthority && chmod 600 /root/.Xauthority

# Configure X11 wrapper
RUN mkdir -p /etc/X11
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Set default session
RUN echo "xfce4-session" > /root/.xsession

# CRITICAL: Configure xrdp for Windows 11 compatibility
RUN cat >/etc/xrdp/xrdp.ini <<'EOF'
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
# Windows 11 compatibility settings
rdp_ssl=yes
ssl_cert_file=/etc/xrdp/xrdp-cert.pem
ssl_key_file=/etc/xrdp/xrdp-key.pem
ssl_verify=no
ssl_ciphers=ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384
rdp_use_ssl=yes
crypto_use_fips=false
; Network settings for Windows 11
tcp_send_buffer_bytes=262144
tcp_recv_buffer_bytes=262144
max_connections=100
; Enable RDP8.0 features
rdp_enhanced_security=yes
; Force TLS 1.2 for Windows 11
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
EOF

# Generate SSL certificates for Windows 11 compatibility
RUN openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/xrdp-key.pem -out /etc/xrdp/xrdp-cert.pem -days 365 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    chmod 600 /etc/xrdp/xrdp-key.pem && \
    chmod 644 /etc/xrdp/xrdp-cert.pem

# CRITICAL: Configure sesman for Windows 11
RUN cat >/etc/xrdp/sesman.ini <<'EOF'
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=true
UserWindowManager=startwm.sh
DefaultWindowManager=startwm.sh
SessionVariables=XDG_CURRENT_DESKTOP=XFCE,XDG_MENU_PREFIX=xfce-,XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg,XDG_DATA_DIRS=/usr/share/xfce4:/usr/share
AllowRootLogin=true
AllowConsoleLogin=true
RootLoginAllowed=true
DisableAuthentication=false
# Windows 11 compatibility
EnableRemoteLogin=true
SessionTimeout=0
DisconnectedTimeLimit=0
IdleTimeLimit=0
KillDisconnected=false
# Use Xorg for better compatibility
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
EOF

# Create Xorg configuration for better Windows 11 compatibility
RUN mkdir -p /etc/X11/xorg.conf.d
RUN cat >/etc/X11/xorg.conf.d/99-dummy.conf <<'EOF'
Section "Device"
    Identifier  "DummyDevice"
    Driver      "dummy"
    Option      "ConstantDPI" "true"
    Option      "NoDDC" "true"
    Option      "IgnoreEDID" "true"
    Option      "UseDisplayDevice" "none"
    Option      "NoRandR" "false"
    VideoRam    256000
EndSection

Section "Monitor"
    Identifier  "DummyMonitor"
    HorizSync   28-80
    VertRefresh 43-60
    Option      "DPMS" "false"
    Option      "Enable" "true"
    Option      "PreferredMode" "1920x1080"
EndSection

Section "Screen"
    Identifier  "DummyScreen"
    Device      "DummyDevice"
    Monitor     "DummyMonitor"
    DefaultDepth 32
    SubSection "Display"
        Depth 32
        Modes "1920x1080" "1280x720" "1024x768" "800x600"
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier  "DummyLayout"
    Screen      "DummyScreen"
    Option      "BlankTime" "0"
    Option      "StandbyTime" "0"
    Option      "SuspendTime" "0"
    Option      "OffTime" "0"
EndSection
EOF

# Create xrdp startup script
RUN cat >/etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
# XRDP startwm.sh for XFCE with Windows 11 compatibility
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export XDG_CURRENT_DESKTOP=XFCE
export XDG_MENU_PREFIX=xfce-
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share:/usr/local/share
export DISABLE_WAYLAND=1
export XDG_RUNTIME_DIR=/run/user/0
export XAUTHORITY=/root/.Xauthority
export HOME=/root
export USER=root
export SHELL=/bin/bash
export DISPLAY=:10
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Create runtime directory
mkdir -p /run/user/0
chmod 700 /run/user/0

# Clean up display locks
rm -f /tmp/.X0-lock /tmp/.X10-lock /tmp/.X11-unix/X0 /tmp/.X11-unix/X10

# Start DBus session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval `dbus-launch --sh-syntax --exit-with-session`
    export DBUS_SESSION_BUS_ADDRESS
fi

# Start XFCE
exec startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Remove light-locker and power manager
RUN apt-get remove -y light-locker xfce4-power-manager || true

# Disable screensaver and power management
RUN mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
RUN cat >/root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="blank-on-battery" type="int" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
  </property>
</channel>
EOF

# Disable screensaver
RUN cat >/root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="enabled" type="bool" value="false"/>
  <property name="lock-enabled" type="bool" value="false"/>
</channel>
EOF

# Create pulse client configuration
RUN mkdir -p /etc/pulse
RUN cat >/etc/pulse/client.conf <<'EOF'
# PulseAudio client configuration for container
default-server = /run/pulse/native
autospawn = no
daemon-binary = /usr/bin/pulseaudio
extra-arguments = --exit-idle-time=-1 --disable-shm=yes --realtime=no
cookie-file = /root/.config/pulse/cookie
enable-shm = no
disable-shm = yes
EOF

# Create start script with Windows 11 compatibility
RUN cat >/start.sh <<'EOF'
#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "Container ID: $(hostname)"
echo "========================================="

# Setup mount namespace and permissions
echo "Setting up mount namespace permissions..."

# Create all necessary directories with proper permissions
mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /root/.config/pulse /tmp/.X11-unix /run/user/0
mkdir -p /tmp/thinclient_drives /var/lib/xrdp /var/log/xrdp
mkdir -p /proc /sys /dev /dev/shm
chmod 1777 /tmp/.X11-unix
chmod 700 /run/user/0
chmod 755 /var/run/xrdp /var/run/xrdp-sesman /tmp/thinclient_drives

# Mount proc and sys if not already mounted
if ! mountpoint -q /proc; then
    mount -t proc proc /proc
fi

if ! mountpoint -q /sys; then
    mount -t sysfs sys /sys
fi

if ! mountpoint -q /dev; then
    mount -t devtmpfs dev /dev
fi

if ! mountpoint -q /dev/shm; then
    mount -t tmpfs tmpfs /dev/shm
fi

# Setup /dev/tty
if [ ! -e /dev/tty ]; then
    mknod -m 666 /dev/tty c 5 0 2>/dev/null || true
fi

# Setup /dev/null and /dev/zero
if [ ! -e /dev/null ]; then
    mknod -m 666 /dev/null c 1 3 2>/dev/null || true
fi

if [ ! -e /dev/zero ]; then
    mknod -m 666 /dev/zero c 1 5 2>/dev/null || true
fi

# Setup /dev/pts
if ! mountpoint -q /dev/pts; then
    mount -t devpts devpts /dev/pts
fi

# Setup /proc/sys/fs/binfmt_misc for wine
if ! mountpoint -q /proc/sys/fs/binfmt_misc; then
    mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || true
fi

# Create Xauthority if missing
touch /root/.Xauthority && chmod 600 /root/.Xauthority

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
pkill -x startxfce4 2>/dev/null || true
pkill -x xfce4-session 2>/dev/null || true
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
echo "✓ pulseaudio configured"

# Start xrdp-sesman
echo "[3/5] Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!
sleep 5

if ps -p $SESMAN_PID > /dev/null 2>&1; then
    echo "✓ xrdp-sesman started (PID: $SESMAN_PID)"
else
    echo "✗ ERROR: xrdp-sesman failed to start"
    echo "Checking sesman log..."
    if [ -f /var/log/xrdp-sesman.log ]; then
        cat /var/log/xrdp-sesman.log
    else
        echo "No sesman log found"
    fi
    exit 1
fi

# Start xrdp
echo "[4/5] Starting xrdp on port 3389..."

# Show system information
echo ""
echo "System Information:"
echo "  Hostname: $(hostname)"
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Disk: $(df -h / | awk 'NR==2 {print $2}')"
echo "  CPU: $(nproc) cores"
echo ""

echo "[5/5] XRDP Server ready!"
echo "========================================="
echo "✓ XRDP Server is ready for Windows 11!"
echo "  Connect to: localhost:3389"
echo "  Username: root"
echo "  Password: ja908070"
echo "  Session: Xorg (Display :10)"
echo "========================================="
echo ""
echo "Windows 11 Connection Settings:"
echo "  - Use RDP Client (mstsc.exe)"
echo "  - Allow TLS 1.2/1.3"
echo "  - Ignore certificate warnings"
echo "  - Use 32-bit color depth"
echo "========================================="
echo ""
echo "Session Information:"
echo "  Display: :10"
echo "  Xauthority: /root/.Xauthority"
echo "  Runtime dir: /run/user/0"
echo "  Pulse socket: /run/pulse/native"
echo "  DBus socket: /run/dbus/system_bus_socket"
echo "  SSL Certificate: /etc/xrdp/xrdp-cert.pem"
echo ""
echo "Mount Information:"
echo "  /proc: $(mount | grep /proc | head -1)"
echo "  /sys: $(mount | grep /sys | head -1)"
echo "  /dev: $(mount | grep /dev | head -1)"
echo ""
echo "To monitor logs:"
echo "  docker exec -it xrdp tail -f /var/log/xrdp.log"
echo "  docker exec -it xrdp tail -f /var/log/xrdp-sesman.log"
echo "  docker exec -it xrdp tail -f /var/log/Xorg.10.log"
echo ""

# Keep the container running with xrdp in foreground
exec /usr/sbin/xrdp --nodaemon
EOF

RUN chmod +x /start.sh

# Create additional script to fix permissions on startup
RUN cat >/fix-permissions.sh <<'EOF'
#!/bin/bash
# Fix xrdp permissions for Windows 11 compatibility
echo "Fixing xrdp permissions for Windows 11..."

# Allow root in xrdp
sed -i 's/^#*allow_root=.*/allow_root=true/g' /etc/xrdp/xrdp.ini
sed -i 's/^#*allow_console=.*/allow_console=true/g' /etc/xrdp/xrdp.ini
sed -i 's/^#*disable_root_login=.*/disable_root_login=false/g' /etc/xrdp/xrdp.ini
sed -i 's/^#*rdp_ssl=.*/rdp_ssl=yes/g' /etc/xrdp/xrdp.ini
sed -i 's/^#*rdp_use_ssl=.*/rdp_use_ssl=yes/g' /etc/xrdp/xrdp.ini

# Allow root in sesman
sed -i 's/^#*AllowRootLogin=.*/AllowRootLogin=true/g' /etc/xrdp/sesman.ini
sed -i 's/^#*RootLoginAllowed=.*/RootLoginAllowed=true/g' /etc/xrdp/sesman.ini
sed -i 's/^#*EnableRemoteLogin=.*/EnableRemoteLogin=true/g' /etc/xrdp/sesman.ini

# Set proper permissions
chmod 755 /etc/xrdp/*.ini
chmod 755 /etc/xrdp/startwm.sh
chmod 600 /root/.Xauthority
chmod 600 /etc/xrdp/xrdp-key.pem
chmod 644 /etc/xrdp/xrdp-cert.pem

echo "Permissions fixed successfully!"
echo "SSL certificate generated for Windows 11"
EOF

RUN chmod +x /fix-permissions.sh

EXPOSE 3389

# Run fix-permissions before starting
CMD ["/bin/bash", "-c", "/fix-permissions.sh && /start.sh"]
