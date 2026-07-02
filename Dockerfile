FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

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
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Set root password
RUN echo "root:ja908070" | chpasswd

# Configure X11
RUN mkdir -p /etc/X11
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Set default session
RUN echo "xfce4-session" > /root/.xsession

# Fix xrdp startup script
RUN cat >/etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export XDG_CURRENT_DESKTOP=XFCE
export XDG_MENU_PREFIX=xfce-
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share
exec startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Configure xrdp
RUN sed -i 's/^#.*port=3389/port=3389/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*use_vsock=.*/use_vsock=false/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*security_layer=.*/security_layer=negotiate/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*crypt_level=.*/crypt_level=high/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*tcp_send_buffer_bytes=.*/tcp_send_buffer_bytes=32768/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*tcp_recv_buffer_bytes=.*/tcp_recv_buffer_bytes=32768/g' /etc/xrdp/xrdp.ini

# Create necessary directories
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/pulse /var/lib/xrdp

# Create pulse client config
RUN mkdir -p /etc/pulse
RUN cat >/etc/pulse/client.conf <<'EOF'
# PulseAudio client configuration
default-server = /run/pulse/native
autospawn = no
daemon-binary = /usr/bin/pulseaudio
extra-arguments = --exit-idle-time=-1
cookie-file = /root/.config/pulse/cookie
enable-shm = no
disable-shm = yes
EOF

# Create start script with mount/namespace support
RUN cat >/start.sh <<'EOF'
#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Create runtime directories with proper permissions
mkdir -p /run/dbus
mkdir -p /var/run/dbus
mkdir -p /run/pulse
mkdir -p /var/run/xrdp
mkdir -p /var/run/xrdp-sesman
mkdir -p /root/.config/pulse
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
chmod 755 /run/dbus
chmod 755 /var/run/dbus

# Clean up stale PID files
echo "Cleaning up stale PID files..."
rm -f /run/dbus/pid
rm -f /var/run/dbus/pid
rm -f /tmp/.X0-lock
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

# Start dbus
echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 1

if pgrep -x "dbus-daemon" > /dev/null; then
    echo "✓ dbus-daemon started (PID: $(pgrep -x dbus-daemon))"
else
    echo "✗ ERROR: dbus-daemon failed to start"
    exit 1
fi

# Start pulseaudio
echo "[2/4] Starting pulseaudio..."
if ! pgrep -x "pulseaudio" > /dev/null; then
    pulseaudio --start --daemonize 2>/dev/null || echo "⚠ Pulseaudio start failed, continuing..."
    sleep 1
    if pgrep -x "pulseaudio" > /dev/null; then
        echo "✓ pulseaudio started (PID: $(pgrep -x pulseaudio))"
    else
        echo "⚠ pulseaudio not running (continuing anyway)"
    fi
else
    echo "✓ pulseaudio already running"
fi

# Start xrdp-sesman
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

# Start xrdp
echo "[4/4] Starting xrdp on port 3389..."
echo "========================================="
echo "✓ XRDP Server is ready!"
echo "========================================="
echo "  Connect to: localhost:3389"
echo "  Username:   root"
echo "  Password:   ja908070"
echo "========================================="

exec /usr/sbin/xrdp --nodaemon
EOF

RUN chmod +x /start.sh

EXPOSE 3389

CMD ["/start.sh"]
