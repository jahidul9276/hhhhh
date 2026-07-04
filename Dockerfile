FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Add i386 architecture for Wine
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
    policykit-1 \
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
    lightdm \
    tzdata \
    locales \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set timezone and locales
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# Set root password
RUN echo "root:ja908070" | chpasswd

# Create necessary directories
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/pulse /var/lib/xrdp /var/log/xrdp

# Configure X11
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Set default X session
RUN echo "xfce4-session" > /root/.xsession

# Create XRDP startup script with proper XFCE configuration
RUN cat >/etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
# XRDP XFCE startup script for container
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export XDG_CURRENT_DESKTOP=XFCE
export XDG_MENU_PREFIX=xfce-
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share

# Disable problematic services
export DISABLE_WAYLAND=1
export XDG_RUNTIME_DIR=/tmp

# Start XFCE
exec startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Configure XRDP
RUN sed -i 's/^port=3389/port=3389/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/^use_vsock=true/use_vsock=false/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/^security_layer=.*/security_layer=negotiate/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/^crypt_level=.*/crypt_level=high/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/^#*max_bpp=.*/max_bpp=32/g' /etc/xrdp/xrdp.ini

# Create PulseAudio configuration
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

# Create main startup script with proper service ordering
RUN cat >/start.sh <<'EOF'
#!/bin/bash
set -e

echo "========================================="
echo "Starting XRDP Container Services"
echo "========================================="

# Create runtime directories with proper permissions
mkdir -p /run/dbus /var/run/dbus /run/pulse
mkdir -p /var/run/xrdp /var/run/xrdp-sesman
mkdir -p /root/.config/pulse /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
chmod 755 /run/pulse

# Clean up stale files
echo "Cleaning up stale files..."
rm -f /run/dbus/pid /var/run/dbus/pid
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
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

# Start D-Bus
echo "[1/4] Starting dbus-daemon..."
dbus-daemon --system --fork
sleep 2

if pgrep -x "dbus-daemon" > /dev/null; then
    echo "✓ dbus-daemon started (PID: $(pgrep -x dbus-daemon))"
else
    echo "⚠ WARNING: dbus-daemon failed to start"
fi

# Start PulseAudio
echo "[2/4] Starting pulseaudio..."
if ! pgrep -x "pulseaudio" > /dev/null; then
    export PULSE_RUNTIME_PATH=/run/pulse
    pulseaudio --start --daemonize --exit-idle-time=-1 -vvvv 2>&1 | tee /var/log/pulse.log || true
    sleep 2
    if pgrep -x "pulseaudio" > /dev/null; then
        echo "✓ pulseaudio started (PID: $(pgrep -x pulseaudio))"
    else
        echo "⚠ WARNING: pulseaudio failed to start"
        echo "   Check /var/log/pulse.log for details"
        # Create dummy socket to prevent errors
        touch /run/pulse/native
    fi
else
    echo "✓ pulseaudio already running"
fi

# Start XRDP session manager
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

# Start XRDP
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

# Create symlink for systemd (optional)
RUN ln -sf /start.sh /usr/local/bin/start-xrdp

EXPOSE 3389

CMD ["/start.sh"]
