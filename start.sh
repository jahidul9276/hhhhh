#!/bin/bash

echo "=========================================="
echo "XRDP Container Starting - Simple Mode"
echo "=========================================="

# Clean up everything
cleanup() {
    echo "Cleaning up old processes..."
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
    echo "Creating directories..."
    mkdir -p /var/run/xrdp
    mkdir -p /var/run/xrdp-sesman
    mkdir -p /run/dbus
    mkdir -p /run/user/0
    mkdir -p /tmp/.X11-unix
    mkdir -p /var/log/xrdp
    
    chmod 1777 /tmp/.X11-unix
    chmod 755 /var/run/xrdp
    chmod 755 /var/run/xrdp-sesman
    chmod 755 /run/dbus
    chmod 755 /run/user/0
}

# Start services
start_services() {
    echo "Starting services..."
    
    # Start D-Bus
    echo "Starting D-Bus..."
    dbus-daemon --system --fork
    sleep 1
    
    # Start PulseAudio
    echo "Starting PulseAudio..."
    pulseaudio --start --daemonize --system --exit-idle-time=-1 2>/dev/null || true
    sleep 1
    
    # Create .Xauthority
    touch /root/.Xauthority
    chmod 600 /root/.Xauthority
}

# Start sesman with proper signal handling
start_sesman() {
    echo "Starting xrdp-sesman..."
    
    # Create sesman config
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

    # Start sesman with exec to keep it in foreground
    /usr/sbin/xrdp-sesman --nodaemon &
    SESMAN_PID=$!
    echo "sesman started with PID: $SESMAN_PID"
    
    # Wait for socket
    echo "Waiting for sesman socket..."
    for i in {1..20}; do
        if [ -S /var/run/xrdp-sesman/sesman.socket ]; then
            echo "✓ sesman socket created at /var/run/xrdp-sesman/sesman.socket"
            return 0
        fi
        sleep 1
    done
    
    # Alternative socket location
    if [ -S /run/xrdp/sockdir/sesman.socket ]; then
        echo "✓ sesman socket created at /run/xrdp/sockdir/sesman.socket"
        ln -sf /run/xrdp/sockdir/sesman.socket /var/run/xrdp-sesman/sesman.socket
        return 0
    fi
    
    echo "✗ Failed to create sesman socket"
    return 1
}

# Start xrdp
start_xrdp() {
    echo "Starting xrdp on port 3389..."
    
    # Create xrdp config
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

    # Start xrdp in foreground
    exec /usr/sbin/xrdp --nodaemon
}

# Monitor sesman
monitor_sesman() {
    while true; do
        if ! pgrep -x "xrdp-sesman" > /dev/null; then
            echo "sesman died! Restarting..."
            /usr/sbin/xrdp-sesman --nodaemon &
        fi
        sleep 5
    done
}

# Main
main() {
    echo "=========================================="
    
    cleanup
    setup_dirs
    
    # Start services
    start_services
    
    # Start sesman
    start_sesman || {
        echo "Failed to start sesman, trying alternative..."
        /usr/sbin/xrdp-sesman --nodaemon --debug &
        sleep 3
    }
    
    # Start monitor in background
    monitor_sesman &
    
    echo "=========================================="
    echo "XRDP Ready!"
    echo "Username: root"
    echo "Password: ja908070"
    echo "=========================================="
    
    # Start xrdp
    start_xrdp
}

# Trap signals
trap 'echo "Stopping services..."; pkill xrdp-sesman; pkill xrdp; exit 0' SIGTERM SIGINT

# Run main
main
