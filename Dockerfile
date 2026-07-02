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
pm-utils \
xserver-xorg-video-dummy \
xserver-xorg-core \
x11-xserver-utils \
systemd \
systemd-sysv \
dbus \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Install Hermes Gateway
RUN curl -fsSL https://raw.githubusercontent.com/hermes/hermes/main/install.sh | bash || \
    wget -qO- https://raw.githubusercontent.com/hermes/hermes/main/install.sh | bash || \
    echo "Hermes installation skipped - will install manually if needed"

# Set root password
RUN echo "root:ja908070" | chpasswd

# Create Xauthority file
RUN touch /root/.Xauthority && chmod 600 /root/.Xauthority

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
export DISABLE_WAYLAND=1
export XDG_RUNTIME_DIR=/run/user/0

mkdir -p /run/user/0
chmod 700 /run/user/0

exec startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Configure xrdp
RUN sed -i 's/^#.*port=3389/port=3389/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*use_vsock=.*/use_vsock=false/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*security_layer=.*/security_layer=negotiate/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*crypt_level=.*/crypt_level=high/g' /etc/xrdp/xrdp.ini

# Fix Xorg configuration
RUN mkdir -p /etc/X11/xrdp
RUN cat >/etc/X11/xrdp/xorg.conf <<'EOF'
Section "Device"
    Identifier  "dummy"
    Driver      "dummy"
    VideoRam    256000
    Option      "NoDDC" "1"
    Option      "IgnoreEDID" "true"
EndSection

Section "Monitor"
    Identifier  "dummy"
    Option      "DPMS" "false"
    HorizSync   28-80
    VertRefresh 43-60
EndSection

Section "Screen"
    Identifier  "default"
    Device      "dummy"
    Monitor     "dummy"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1024x768" "800x600" "640x480"
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier  "default"
    Screen      "default"
EndSection
EOF

# Remove light-locker
RUN apt-get remove -y light-locker || true

# Disable unnecessary services
RUN mkdir -p /root/.config/autostart
RUN cat > /root/.config/autostart/light-locker.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Light Locker
Exec=/bin/true
Hidden=true
NoDisplay=true
X-GNOME-Autostart-enabled=false
EOF

RUN cat > /root/.config/autostart/xfce4-power-manager.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Power Manager
Exec=/bin/true
Hidden=true
NoDisplay=true
X-GNOME-Autostart-enabled=false
EOF

# Create necessary directories
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/pulse /var/lib/xrdp /run/user/0

# Create pulse client config
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

# Create start script with Hermes support
RUN cat >/start.sh <<'EOF'
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

# Clean up stale files
echo "Cleaning up stale files..."
rm -f /run/dbus/pid /var/run/dbus/pid /tmp/.X0-lock /tmp/.X11-unix/X0
rm -f /tmp/.X11-unix/X10 /tmp/.X11-unix/X11
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
pulseaudio --start --daemonize --exit-idle-time=-1 2>/dev/null || echo "⚠ Pulseaudio not available"
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
    exit 1
fi

# Start xrdp
echo "[4/5] Starting xrdp on port 3389..."
/usr/sbin/xrdp --nodaemon &
XRDP_PID=$!
sleep 3

if ps -p $XRDP_PID > /dev/null 2>&1; then
    echo "✓ xrdp started (PID: $XRDP_PID)"
else
    echo "✗ ERROR: xrdp failed to start"
    exit 1
fi

# Start Hermes Gateway if installed
echo "[5/5] Checking Hermes Gateway..."
if command -v hermes &> /dev/null; then
    echo "✓ Hermes found, starting gateway..."
    hermes gateway run &
    HERMES_PID=$!
    echo "✓ Hermes gateway started (PID: $HERMES_PID)"
else
    echo "⚠ Hermes not installed - skipping"
fi

echo "========================================="
echo "✓ All services are ready!"
echo "========================================="
echo "  XRDP:      localhost:3389"
echo "  Username:  root"
echo "  Password:  ja908070"
echo "  Hermes:    $(command -v hermes &> /dev/null && echo '✓ Running' || echo '✗ Not installed')"
echo "========================================="

# Keep container running
while true; do
    # Check if xrdp is still running
    if ! pgrep -x "xrdp" > /dev/null; then
        echo "⚠ WARNING: xrdp process died! Restarting..."
        /usr/sbin/xrdp --nodaemon &
    fi
    
    if ! pgrep -x "xrdp-sesman" > /dev/null; then
        echo "⚠ WARNING: xrdp-sesman died! Restarting..."
        /usr/sbin/xrdp-sesman --nodaemon &
    fi
    
    sleep 30
done
EOF

RUN chmod +x /start.sh

EXPOSE 3389

CMD ["/start.sh"]
