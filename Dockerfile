FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
xrdp \
tigervnc-standalone-server \
xfce4 \
xfce4-goodies \
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
procps \
iproute2 \
x11-utils \
xauth \
openssl \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Set root password
RUN echo "root:ja908070" | chpasswd

# Set default session
RUN echo "xfce4-session" > /root/.xsession

# xrdp startup script (runs inside the Xvnc-backed session)
RUN cat >/etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export XDG_CURRENT_DESKTOP=XFCE
export XDG_MENU_PREFIX=xfce-
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share
export XDG_RUNTIME_DIR=/tmp
exec startxfce4
EOF
RUN chmod +x /etc/xrdp/startwm.sh

# ---- xrdp.ini: keep ONLY the Xvnc session type ----
# (No Xorg/X11rdp entries -- those require kernel/device access this
#  container doesn't have. Xvnc is pure userspace, no privilege needed.)
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
allow_root=true
allow_console=true
rdp_ssl=yes
ssl_cert_file=/etc/xrdp/xrdp-cert.pem
ssl_key_file=/etc/xrdp/xrdp-key.pem
tls_min_version=1.2
tls_max_version=1.3

[Xvnc]
name=Xvnc
lib=libvnc.so
username=ask
password=ask
ip=127.0.0.1
port=-1
EOF

# Generate SSL certificates
RUN openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/xrdp-key.pem -out /etc/xrdp/xrdp-cert.pem -days 365 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    chmod 600 /etc/xrdp/xrdp-key.pem && \
    chmod 644 /etc/xrdp/xrdp-cert.pem

# ---- sesman.ini: AllowRootLogin belongs in [Security]; Xvnc params in [Xvnc] ----
RUN cat >/etc/xrdp/sesman.ini <<'EOF'
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=true
UserWindowManager=startwm.sh
DefaultWindowManager=startwm.sh

[Security]
AllowRootLogin=true
MaxLoginRetry=4
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

[Xvnc]
param=Xvnc
param=-bs
param=-nolisten
param=tcp
param=-localhost
param=-dpi
param=96

[Chansrv]
FuseMountName=thinclient_drives
EOF

# Create necessary directories
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/pulse /var/lib/xrdp

# Pulse client config
RUN mkdir -p /etc/pulse
RUN cat >/etc/pulse/client.conf <<'EOF'
default-server = /run/pulse/native
autospawn = no
daemon-binary = /usr/bin/pulseaudio
extra-arguments = --exit-idle-time=-1
cookie-file = /root/.config/pulse/cookie
enable-shm = no
disable-shm = yes
EOF

# Start script
RUN cat >/start.sh <<'EOF'
#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services (Xvnc backend)"
echo "========================================="

mkdir -p /run/dbus /var/run/dbus /run/pulse /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /root/.config/pulse /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

echo "Cleaning up stale PID files..."
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock
rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp-sesman/xrdp-sesman.pid /run/pulse/pid

echo "Cleaning up leftover processes..."
pkill -x dbus-daemon 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
pkill -x Xvnc 2>/dev/null || true
sleep 2

echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 1
pgrep -x dbus-daemon >/dev/null && echo "✓ dbus-daemon started" || { echo "✗ dbus-daemon failed"; exit 1; }

echo "[2/4] Starting pulseaudio..."
export PULSE_RUNTIME_PATH=/run/pulse
pulseaudio --start --daemonize --exit-idle-time=-1 2>/dev/null || echo "⚠ pulseaudio failed, continuing..."

echo "[3/4] Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!
sleep 3
ps -p $SESMAN_PID >/dev/null 2>&1 && echo "✓ xrdp-sesman started (PID: $SESMAN_PID)" || { echo "✗ xrdp-sesman failed"; tail -30 /var/log/xrdp-sesman.log 2>/dev/null; exit 1; }

echo "[4/4] Starting xrdp on port 3389..."
echo "========================================="
echo "✓ XRDP Server is ready! (Xvnc backend, no privilege required)"
echo "  Connect to: <your-railway-domain>:3389 (TCP proxy) or localhost:3389"
echo "  Username:   root"
echo "  Password:   ja908070"
echo "========================================="

exec /usr/sbin/xrdp --nodaemon
EOF
RUN chmod +x /start.sh

EXPOSE 3389
CMD ["/start.sh"]
