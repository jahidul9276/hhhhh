#!/bin/bash

echo "=========================================="
echo "XRDP Container Starting..."
echo "Username: xrdpuser"
echo "Password: ja908070"
echo "=========================================="

# Clean up
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
}

# Setup directories
setup_dirs() {
    echo "Creating directories..."
    mkdir -p /var/run/xrdp
    mkdir -p /var/run/xrdp-sesman
    mkdir -p /run/dbus
    mkdir -p /run/user/1000
    mkdir -p /tmp/.X11-unix
    mkdir -p /var/log/xrdp
    
    chmod 1777 /tmp/.X11-unix
    chmod 755 /var/run/xrdp
    chmod 755 /var/run/xrdp-sesman
    chmod 755 /run/dbus
    chmod 755 /run/user/1000
}

# Configure sesman
configure_sesman() {
    echo "Configuring sesman..."
    
    cat > /etc/xrdp/sesman.ini <<'EOF'
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=true
UserWindowManager=startxfce4
DefaultWindowManager=startxfce4
MaxSessions=10

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
KillDisconnected=false
DisconnectedTimeLimit=0
IdleTimeLimit=0
Policy=Default
EOF

    echo "sesman configured"
}

# Start services
start_services() {
    echo "Starting services..."
    
    # Start D-Bus
    echo "Starting D-Bus..."
    dbus-daemon --system --fork
    sleep 2
    
    # Start PulseAudio
    echo "Starting PulseAudio..."
    pulseaudio --start --daemonize --system --exit-idle-time=-1 2>/dev/null || true
    sleep 2
    
    # Create .Xauthority for user
    touch /home/xrdpuser/.Xauthority
    chown xrdpuser:xrdpuser /home/xrdpuser/.Xauthority
    chmod 600 /home/xrdpuser/.Xauthority
}

# Start sesman
start_sesman() {
    echo "Starting xrdp-sesman..."
    
    /usr/sbin/xrdp-sesman --nodaemon &
    SESMAN_PID=$!
    echo "sesman started with PID: $SESMAN_PID"
    
    # Wait for socket
    echo "Waiting for sesman socket..."
    for i in {1..20}; do
        if [ -S /var/run/xrdp-sesman/sesman.socket ]; then
            echo "✓ sesman socket created"
            return 0
        fi
        sleep 1
    done
    
    echo "✗ Failed to create sesman socket"
    return 1
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

# Start xrdp
start_xrdp() {
    echo "Starting xrdp on port 3389..."
    exec /usr/sbin/xrdp --nodaemon
}

# Main
main() {
    cleanup
    setup_dirs
    configure_sesman
    start_services
    
    start_sesman || {
        echo "Failed to start sesman, trying alternative..."
        /usr/sbin/xrdp-sesman --nodaemon --debug &
        sleep 3
    }
    
    monitor_sesman &
    
    echo "=========================================="
    echo "XRDP Ready!"
    echo "Username: xrdpuser"
    echo "Password: ja908070"
    echo "=========================================="
    
    start_xrdp
}

trap 'echo "Stopping services..."; pkill xrdp-sesman; pkill xrdp; exit 0' SIGTERM SIGINT

main
