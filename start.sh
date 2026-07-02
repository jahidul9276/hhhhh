#!/bin/bash

set -e

echo "=========================================="
echo "XRDP Container Starting..."
echo "=========================================="

# Function to log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Clean up everything
cleanup() {
    log "Cleaning up old processes..."
    pkill xrdp 2>/dev/null || true
    pkill xrdp-sesman 2>/dev/null || true
    pkill Xorg 2>/dev/null || true
    pkill pulseaudio 2>/dev/null || true
    pkill dbus-daemon 2>/dev/null || true
    
    rm -f /var/run/xrdp/xrdp.pid 2>/dev/null || true
    rm -f /var/run/xrdp-sesman/sesman.pid 2>/dev/null || true
    rm -f /var/run/xrdp-sesman/sesman.socket 2>/dev/null || true
    rm -f /tmp/.X11-unix/X0 2>/dev/null || true
    rm -f /var/run/dbus/pid 2>/dev/null || true
}

# Setup directories
setup_dirs() {
    log "Creating directories..."
    mkdir -p /var/run/xrdp
    mkdir -p /var/run/xrdp-sesman
    mkdir -p /run/dbus
    mkdir -p /run/user/0
    mkdir -p /tmp/.X11-unix
    mkdir -p /var/log/xrdp
    mkdir -p /root/.config/xfce4
    mkdir -p /root/.cache
    mkdir -p /root/.local/share
    
    chmod 1777 /tmp/.X11-unix
    chmod 755 /var/run/xrdp
    chmod 755 /var/run/xrdp-sesman
    chmod 755 /run/dbus
    chmod 755 /run/user/0
    chmod 700 /root/.config
    chmod 700 /root/.cache
}

# Configure sesman for root login
configure_sesman() {
    log "Configuring sesman for root login..."
    
    # Create full sesman config
    cat > /etc/xrdp/sesman.ini <<'EOF'
[Xorg]
param=Xorg
param=-config
param=xrdp/xorg.conf
param=-noreset
param=-nolisten
param=tcp
param=-logfile
param=.xorgxrdp.%s.log

[Xvnc]
param=Xvnc
param=-bs
param=-auth
param=.Xauthority
param=-geometry
param=%%GEOMETRY%%
param=-depth
param=%%COLORDEPTH%%
param=-rfbauth
param=.vncpasswd
param=-localhost
param=-dpi
param=%%DPI%%

[Chansrv]
param=chansrv
param=-audio
param=-videofifo
param=/tmp/xrdp-video-fifo
param=-videopidfifo
param=/tmp/xrdp-video-pid-fifo

[SessionVariables]
X11DisplayOffset=10
MaxDisplayNumber=10
AllowRootLogin=true
AllowConsole=true
EnableUserWindowManager=true
UserWindowManager=startxfce4
DefaultWindowManager=startxfce4
FuseMountName=thinclient_drives
FuseMountPath=/tmp/fuse_mount
Autorun=
KillDisconnected=false
DisconnectedTimeLimit=0
IdleTimeLimit=0
Policy=Default
EOF

    log "sesman configured for root login"
}

# Configure xrdp
configure_xrdp() {
    log "Configuring xrdp..."
    
    cat > /etc/xrdp/xrdp.ini <<'EOF'
[Globals]
ini_version=1
fork=true
port=3389
use_vsock=false
crypt_level=low
channel_code=1
max_bpp=32
xserverbpp=24
ssl_protocols=TLSv1.2,TLSv1.3
ssl_ciphers=HIGH
enable_fuse=true
fuse_mount_name=thinclient_drives
fuse_mount_path=/tmp/fuse_mount
fuse_allow_other=true

[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20

[Xvnc]
name=Xvnc
lib=libvnc.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=1

[XRDP]
name=XRDP
lib=libxrdp.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=10

[Chansrv]
name=Chansrv
lib=libxrdpchansrv.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=3
EOF

    log "xrdp configured"
}

# Start services
start_services() {
    log "Starting services..."
    
    # Start D-Bus
    log "Starting D-Bus..."
    dbus-daemon --system --fork
    sleep 2
    
    # Start PulseAudio
    log "Starting PulseAudio..."
    pulseaudio --start --daemonize --system --exit-idle-time=-1 2>/dev/null || true
    sleep 2
    
    # Create .Xauthority
    touch /root/.Xauthority
    chmod 600 /root/.Xauthority
}

# Start sesman
start_sesman() {
    log "Starting xrdp-sesman..."
    
    # Start sesman
    /usr/sbin/xrdp-sesman --nodaemon &
    SESMAN_PID=$!
    log "sesman started with PID: $SESMAN_PID"
    
    # Wait for socket
    log "Waiting for sesman socket..."
    for i in {1..20}; do
        if [ -S /var/run/xrdp-sesman/sesman.socket ]; then
            log "✓ sesman socket created at /var/run/xrdp-sesman/sesman.socket"
            return 0
        fi
        sleep 1
    done
    
    log "✗ Failed to create sesman socket"
    return 1
}

# Monitor sesman
monitor_sesman() {
    while true; do
        if ! pgrep -x "xrdp-sesman" > /dev/null; then
            log "sesman died! Restarting..."
            /usr/sbin/xrdp-sesman --nodaemon &
        fi
        sleep 5
    done
}

# Start xrdp
start_xrdp() {
    log "Starting xrdp on port 3389..."
    exec /usr/sbin/xrdp --nodaemon
}

# Main
main() {
    log "=========================================="
    log "Initializing XRDP Container"
    log "=========================================="
    
    cleanup
    setup_dirs
    configure_sesman
    configure_xrdp
    start_services
    
    # Start sesman
    start_sesman || {
        log "Failed to start sesman, trying alternative..."
        /usr/sbin/xrdp-sesman --nodaemon --debug &
        sleep 3
    }
    
    # Start monitor in background
    monitor_sesman &
    
    log "=========================================="
    log "XRDP Ready!"
    log "Username: root"
    log "Password: ja908070"
    log "=========================================="
    log "Port: 3389"
    log "=========================================="
    
    # Start xrdp
    start_xrdp
}

# Trap signals
trap 'log "Stopping services..."; pkill xrdp-sesman; pkill xrdp; exit 0' SIGTERM SIGINT

# Run main
main
