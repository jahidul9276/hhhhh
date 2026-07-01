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
    mkdir -p /var/run/xrdp /var/run/xrdp-sesman
    mkdir -p /root/.config/pulse
    mkdir -p /var/run/xrdp/sockdir
    
    # Set proper permissions
    chmod 1777 /tmp/.X11-unix
    chmod 755 /run/dbus /var/run/dbus
    chmod 755 /var/run/xrdp /var/run/xrdp-sesman
    chmod 755 /run/user/0
    chmod 755 /var/run/xrdp/sockdir
    
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
    rm -f /var/run/xrdp/xrdp.sock 2>/dev/null || true
    
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
    if ! dbus-daemon --system --fork --print-pid 2>/dev/null; then
        log "Warning: dbus-daemon failed with print-pid, trying without..."
        dbus-daemon --system --fork
    fi
    
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
    
    # Start pulseaudio with multiple fallback methods
    if ! pulseaudio --start --daemonize --system \
        --exit-idle-time=-1 \
        --realtime \
        --log-level=1 \
        --load="module-native-protocol-unix socket=/run/pulse/native" \
        2>/dev/null; then
        
        log "First pulseaudio attempt failed, trying fallback..."
        if ! pulseaudio --start --daemonize --system --exit-idle-time=-1 2>/dev/null; then
            log "Second pulseaudio attempt failed, trying simple start..."
            pulseaudio --start --daemonize 2>/dev/null || {
                log "Warning: PulseAudio failed to start"
                return 1
            }
        fi
    fi
    
    sleep 2
    
    # Check if pulseaudio is running
    if is_running pulseaudio; then
        log "PulseAudio started successfully"
    else
        log "Warning: PulseAudio may not be running properly"
        return 1
    fi
}

# Start XRDP session manager
start_xrdp_sesman() {
    log "Starting XRDP session manager..."
    
    # Kill existing xrdp-sesman
    pkill xrdp-sesman 2>/dev/null || true
    sleep 2
    
    # Clean up old socket files
    rm -f /var/run/xrdp-sesman/sesman.pid 2>/dev/null || true
    rm -f /var/run/xrdp-sesman/sesman.socket 2>/dev/null || true
    rm -f /var/run/xrdp-sesman/sesman.ini 2>/dev/null || true
    
    # Create sesman configuration if missing
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
    
    # Create xrdp configuration if missing
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
    
    # Start xrdp-sesman in background with debug
    /usr/sbin/xrdp-sesman --nodaemon --debug &
    XRDP_SESMAN_PID=$!
    
    sleep 5
    
    # Check if xrdp-sesman is running
    if is_running xrdp-sesman; then
        log "XRDP session manager started successfully (PID: $XRDP_SESMAN_PID)"
        
        # Check if socket exists
        if [ -S /var/run/xrdp-sesman/sesman.socket ]; then
            log "Session manager socket created successfully"
            ls -la /var/run/xrdp-sesman/
        else
            log "Warning: Session manager socket not found"
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
    rm -f /var/run/xrdp/xrdp.sock 2>/dev/null || true
    
    # Wait for sesman socket to be ready
    local max_attempts=10
    local attempt=0
    while [ ! -S /var/run/xrdp-sesman/sesman.socket ] && [ $attempt -lt $max_attempts ]; do
        log "Waiting for sesman socket... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    if [ -S /var/run/xrdp-sesman/sesman.socket ]; then
        log "Sesman socket is ready"
    else
        log "Warning: Sesman socket still not ready, attempting to continue..."
    fi
    
    # Start xrdp in foreground
    log "XRDP listening on port 3389"
    exec /usr/sbin/xrdp --nodaemon
}

# Health check function
health_check() {
    log "Running health check..."
    
    # Check if xrdp is listening on port 3389
    if netstat -tlnp 2>/dev/null | grep -q ":3389"; then
        log "Health check: XRDP is listening on port 3389 ✓"
    else
        log "Health check: XRDP is NOT listening on port 3389 ✗"
    fi
    
    # Check socket
    if [ -S /var/run/xrdp-sesman/sesman.socket ]; then
        log "Health check: Session manager socket exists ✓"
    else
        log "Health check: Session manager socket missing ✗"
    fi
    
    # Check running processes
    for service in xrdp xrdp-sesman pulseaudio dbus-daemon; do
        if is_running "$service"; then
            log "Health check: $service is running ✓"
        else
            log "Health check: $service is NOT running ✗"
        fi
    done
}

# Main execution
main() {
    log "Initializing XRDP container..."
    
    # Setup environment
    export DISPLAY=:0
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
    
    # Setup permissions and mounts
    setup_permissions
    fix_mounts
    
    # Start services in correct order
    start_dbus || {
        log "Critical: D-Bus failed to start, but continuing..."
    }
    
    start_pulseaudio || {
        log "Warning: PulseAudio failed to start, audio may not work"
    }
    
    start_xrdp_sesman || {
        log "Error: XRDP session manager failed to start"
        # Try to fix with alternative method
        log "Attempting alternative start method..."
        /usr/sbin/xrdp-sesman --nodaemon &
        sleep 5
    }
    
    # Create .Xauthority if it doesn't exist
    if [ ! -f /root/.Xauthority ]; then
        touch /root/.Xauthority
        chmod 600 /root/.Xauthority
    fi
    
    # Run health check
    health_check
    
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
