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

# Get local IP
get_ip() {
    # Try to get IP from container
    LOCAL_IP=$(ip addr show | grep -E "inet (10\.|172\.|192\.168\.)" | head -1 | awk '{print $2}' | cut -d/ -f1)
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="127.0.0.1"
    fi
    echo "Local IP: $LOCAL_IP"
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
    
    # Start with explicit bind address
    /usr/sbin/xrdp-sesman --nodaemon --bind 127.0.0.1 &
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
            /usr/sbin/xrdp-sesman --nodaemon --bind 127.0.0.1 &
        fi
        sleep 5
    done
}

# Start xrdp
start_xrdp() {
    echo "Starting xrdp on port 3389..."
    
    # Bind to all interfaces
    exec /usr/sbin/xrdp --nodaemon --bind 0.0.0.0
}

# Main
main() {
    get_ip
    cleanup
    setup_dirs
    start_services
    
    # Ensure xrdp.ini has correct IP
    sed -i "s/^ip=.*/ip=127.0.0.1/g" /etc/xrdp/xrdp.ini
    
    start_sesman || {
        echo "Failed to start sesman, trying alternative..."
        /usr/sbin/xrdp-sesman --nodaemon --bind 127.0.0.1 --debug &
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
