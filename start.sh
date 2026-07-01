#!/bin/bash

set -e

echo "=========================================="
echo "XRDP Container Starting..."
echo "=========================================="

# Function to check if process is running
is_running() {
    pgrep -x "$1" > /dev/null 2>&1
}

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Setup proper permissions
setup_permissions() {
    log "Setting up proper permissions..."
    
    # Create necessary directories
    mkdir -p /run/dbus /var/run/dbus /tmp/.X11-unix /run/user/0
    mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/xrdp /run/xrdp/sockdir
    mkdir -p /root/.config/pulse
    mkdir -p /var/log/xrdp
    
    # Set proper permissions
    chmod 1777 /tmp/.X11-unix
    chmod 755 /run/dbus /var/run/dbus
    chmod 755 /var/run/xrdp /var/run/xrdp-sesman
    chmod 755 /run/user/0
    chmod 755 /run/xrdp /run/xrdp/sockdir
    chmod 755 /var/log/xrdp
    
    # Create pulse cookie
    if [ ! -f /root/.config/pulse/cookie ]; then
        touch /root/.config/pulse/cookie
    fi
    chmod 600 /root/.config/pulse/cookie
    
    # Create .Xauthority
    if [ ! -f /root/.Xauthority ]; then
        touch /root/.Xauthority
    fi
    chmod 600 /root/.Xauthority
    
    # Remove stale sockets
    rm -f /var/run/xrdp-sesman/sesman.socket 2>/dev/null || true
    rm -f /run/xrdp/sockdir/sesman.socket 2>/dev/null || true
    rm -f /var/run/xrdp/xrdp.sock 2>/dev/null || true
    rm -f /tmp/.X11-unix/X0 2>/dev/null || true
    
    log "Permissions setup complete"
}

# Fix mount/namespace permissions
fix_mounts() {
    log "Fixing mount/namespace permissions..."
    
    # Remount /proc and /sys with proper permissions
    mount -t proc proc /proc -o remount,rw 2>/dev/null || {
        log "Warning: Could not remount /proc"
    }
    
    mount -t sysfs sys /sys -o remount,rw 2>/dev/null || {
        log "Warning: Could not remount /sys"
    }
    
    log "Mount fixes completed"
}

# Start D-Bus
start_dbus() {
    log "Starting D-Bus daemon..."
    
    # Kill existing dbus if any
    pkill dbus-daemon 2>/dev/null || true
    sleep 1
    
    # Clean up old pid file
    rm -f /run/dbus/pid 2>/dev/null || true
    rm -f /var/run/dbus/pid 2>/dev/null || true
    
    # Start dbus
    dbus-daemon --system --fork
    
    sleep 2
    
    # Verify dbus is running
    if is_running dbus-daemon; then
        log "D-Bus started successfully"
    else
        log "Error: D-Bus failed to start"
        return 1
    fi
}

# Start PulseAudio
start_pulseaudio() {
    log "Starting PulseAudio..."
    
    # Kill existing pulseaudio
    pkill pulseaudio 2>/dev/null || true
    sleep 2
    
    # Start pulseaudio
    pulseaudio --start --daemonize --system --exit-idle-time=-1 2>/dev/null || \
    pulseaudio --start --daemonize 2>/dev/null || {
        log "Warning: PulseAudio failed to start"
        return 1
    }
    
    sleep 2
    
    if is_running pulseaudio; then
        log "PulseAudio started successfully"
    else
        log "Warning: PulseAudio may not be running properly"
        return 1
    fi
}

# Start XRDP session manager (KEEP IT RUNNING)
start_xrdp_sesman() {
    log "Starting XRDP session manager..."
    
    # Kill existing xrdp-sesman
    pkill xrdp-sesman 2>/dev/null || true
    sleep 2
    
    # Clean up old socket files
    rm -f /var/run/xrdp-sesman/sesman.pid 2>/dev/null || true
    rm -f /var/run/xrdp-sesman/sesman.socket 2>/dev/null || true
    rm -f /run/xrdp/sockdir/sesman.socket 2>/dev/null || true
    
    # Create sesman configuration
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
    
    # Start xrdp-sesman with nohup to keep it running
    nohup /usr/sbin/xrdp-sesman --nodaemon > /var/log/xrdp-sesman.log 2>&1 &
    XRDP_SESMAN_PID=$!
    
    log "Waiting for sesman to initialize..."
    sleep 5
    
    # Check if xrdp-sesman is running
    if is_running xrdp-sesman; then
        log "XRDP session manager started successfully (PID: $XRDP_SESMAN_PID)"
        
        # Check socket
        if [ -S /run/xrdp/sockdir/sesman.socket ]; then
            log "Session manager socket created at /run/xrdp/sockdir/sesman.socket"
        elif [ -S /var/run/xrdp-sesman/sesman.socket ]; then
            log "Session manager socket created at /var/run/xrdp-sesman/sesman.socket"
            # Create symlink
            ln -sf /var/run/xrdp-sesman/sesman.socket /run/xrdp/sockdir/sesman.socket
        else
            log "Warning: No socket found, trying to find..."
            find /var/run /run -name "*.socket" 2>/dev/null | grep sesman || true
        fi
    else
        log "Error: XRDP session manager failed to start"
        return 1
    fi
}

# Start XRDP
start_xrdp() {
    log "Starting XRDP server..."
    
    # Kill existing xrdp
    pkill xrdp 2>/dev/null || true
    sleep 2
    
    # Clean up old pid file
    rm -f /var/run/xrdp/xrdp.pid 2>/dev/null || true
    
    # Create xrdp configuration
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
allow_channels=true
allow_multimon=true
bitmap_compression=true
bulk_compression=true
hidelogwindow=true
tcp_send_buffer_bytes=32768
tcp_recv_buffer_bytes=32768

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
    
    # Wait for sesman socket
    local max_attempts=20
    local attempt=0
    local socket_found=0
    
    while [ $attempt -lt $max_attempts ]; do
        if [ -S /run/xrdp/sockdir/sesman.socket ]; then
            log "Sesman socket found at /run/xrdp/sockdir/sesman.socket"
            socket_found=1
            break
        elif [ -S /var/run/xrdp-sesman/sesman.socket ]; then
            log "Sesman socket found at /var/run/xrdp-sesman/sesman.socket"
            ln -sf /var/run/xrdp-sesman/sesman.socket /run/xrdp/sockdir/sesman.socket
            socket_found=1
            break
        else
            log "Waiting for sesman socket... (attempt $((attempt+1))/$max_attempts)"
            sleep 2
            attempt=$((attempt + 1))
        fi
    done
    
    if [ $socket_found -eq 0 ]; then
        log "Warning: No sesman socket found after $max_attempts attempts"
    fi
    
    # Start xrdp in foreground
    log "XRDP listening on port 3389"
    exec /usr/sbin/xrdp --nodaemon
}

# Create xorg configuration for X11
create_xorg_conf() {
    log "Creating Xorg configuration..."
    
    cat > /etc/X11/xorg.conf <<'EOF'
Section "Device"
    Identifier  "Configured Video Device"
    Driver      "modesetting"
    Option      "SWcursor"
    Option      "AccelMethod" "none"
EndSection

Section "Monitor"
    Identifier  "Configured Monitor"
    Option      "DPMS" "false"
    Option      "IgnoreEDIDChecksum" "true"
EndSection

Section "Screen"
    Identifier  "Default Screen"
    Monitor     "Configured Monitor"
    Device      "Configured Video Device"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080" "1600x900" "1366x768" "1280x720" "1024x768"
    EndSubSection
EndSection
EOF
}

# Main execution
main() {
    log "Initializing XRDP container..."
    
    # Setup environment
    export DISPLAY=:0
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
    export XRDP_SOCKET_PATH=/run/xrdp/sockdir/sesman.socket
    export XDG_RUNTIME_DIR=/run/user/0
    export HOME=/root
    
    # Setup permissions and mounts
    setup_permissions
    fix_mounts
    
    # Create Xorg config
    create_xorg_conf
    
    # Start services in correct order
    log "Starting services in order..."
    
    start_dbus || log "Warning: D-Bus failed"
    sleep 2
    
    start_pulseaudio || log "Warning: PulseAudio failed"
    sleep 2
    
    # Start sesman and keep it running
    start_xrdp_sesman || {
        log "Error: XRDP session manager failed to start"
        # Try alternative
        log "Trying alternative start method..."
        /usr/sbin/xrdp-sesman --nodaemon &
        sleep 5
    }
    
    # Create .Xauthority
    if [ ! -f /root/.Xauthority ]; then
        touch /root/.Xauthority
        chmod 600 /root/.Xauthority
    fi
    
    # Start XFCE session for root
    mkdir -p /root/.config/xfce4
    mkdir -p /root/.cache
    
    log "=========================================="
    log "All services started successfully!"
    log "=========================================="
    log "XRDP is ready on port 3389"
    log "Username: root"
    log "Password: ja908070"
    log "=========================================="
    
    # Start XRDP (this will run in foreground)
    start_xrdp
}

# Trap signals for graceful shutdown
trap 'log "Received shutdown signal. Stopping services..."; \
      pkill xrdp 2>/dev/null || true; \
      pkill xrdp-sesman 2>/dev/null || true; \
      pkill pulseaudio 2>/dev/null || true; \
      pkill dbus-daemon 2>/dev/null || true; \
      log "Services stopped. Exiting."; \
      exit 0' SIGTERM SIGINT

# Run main function
main

# If xrdp fails, keep container alive for debugging
log "XRDP exited unexpectedly. Keeping container alive for debugging..."
while true; do
    sleep 60
done
