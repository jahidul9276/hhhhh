#!/bin/bash

echo "=========================================="
echo "XRDP Container Starting (Ubuntu)"
echo "=========================================="

# Function to log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Clean up old processes
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
    rm -f /run/dbus/pid 2>/dev/null || true
}

# Setup directories
setup_dirs() {
    log "Creating directories..."
    mkdir -p /var/run/xrdp
    mkdir -p /var/run/xrdp-sesman
    mkdir -p /run/dbus
    mkdir -p /run/user/1000
    mkdir -p /tmp/.X11-unix
    mkdir -p /var/log/xrdp
    mkdir -p /var/log/xrdp-sesman
    mkdir -p /home/xrdpuser/.config/pulse
    mkdir -p /home/xrdpuser/.cache
    mkdir -p /home/xrdpuser/.local/share
    
    chmod 1777 /tmp/.X11-unix
    chmod 755 /var/run/xrdp
    chmod 755 /var/run/xrdp-sesman
    chmod 755 /run/dbus
    chmod 755 /run/user/1000
    chmod 755 /var/log/xrdp
    chmod 700 /home/xrdpuser/.config
    chmod 700 /home/xrdpuser/.cache
}

# Setup pulse audio
setup_pulse() {
    log "Setting up PulseAudio..."
    
    # Create pulse cookie
    if [ ! -f /home/xrdpuser/.config/pulse/cookie ]; then
        touch /home/xrdpuser/.config/pulse/cookie
        chown xrdpuser:xrdpuser /home/xrdpuser/.config/pulse/cookie
        chmod 600 /home/xrdpuser/.config/pulse/cookie
    fi
    
    # Copy pulse configuration
    cp /etc/pulse/client.conf /home/xrdpuser/.config/pulse/client.conf 2>/dev/null || true
    chown xrdpuser:xrdpuser /home/xrdpuser/.config/pulse/client.conf 2>/dev/null || true
}

# Start services
start_services() {
    log "Starting services..."
    
    # Start D-Bus
    log "Starting D-Bus..."
    if ! pgrep -x "dbus-daemon" > /dev/null; then
        dbus-daemon --system --fork
    fi
    sleep 2
    
    # Start PulseAudio
    log "Starting PulseAudio..."
    if ! pgrep -x "pulseaudio" > /dev/null; then
        pulseaudio --start --daemonize --system --exit-idle-time=-1 2>/dev/null || \
        pulseaudio --start --daemonize --exit-idle-time=-1 2>/dev/null || \
        pulseaudio --start --daemonize 2>/dev/null || true
    fi
    sleep 2
    
    # Create .Xauthority for user
    if [ ! -f /home/xrdpuser/.Xauthority ]; then
        touch /home/xrdpuser/.Xauthority
        chown xrdpuser:xrdpuser /home/xrdpuser/.Xauthority
        chmod 600 /home/xrdpuser/.Xauthority
    fi
}

# Start sesman
start_sesman() {
    log "Starting xrdp-sesman..."
    
    # Check if sesman is already running
    if pgrep -x "xrdp-sesman" > /dev/null; then
        log "sesman already running, killing it..."
        pkill xrdp-sesman
        sleep 2
    fi
    
    # Start sesman
    /usr/sbin/xrdp-sesman --nodaemon &
    SESMAN_PID=$!
    log "sesman started with PID: $SESMAN_PID"
    
    # Wait for socket
    log "Waiting for sesman socket..."
    for i in {1..30}; do
        if [ -S /var/run/xrdp-sesman/sesman.socket ]; then
            log "✓ sesman socket created successfully"
            return 0
        fi
        sleep 1
        if [ $((i % 5)) -eq 0 ]; then
            log "Still waiting for socket... ($i seconds)"
        fi
    done
    
    # Check if sesman is still running
    if ! pgrep -x "xrdp-sesman" > /dev/null; then
        log "✗ sesman died, trying to restart..."
        /usr/sbin/xrdp-sesman --nodaemon --debug &
        sleep 5
    fi
    
    log "✗ Failed to create sesman socket"
    return 1
}

# Monitor sesman
monitor_sesman() {
    while true; do
        if ! pgrep -x "xrdp-sesman" > /dev/null; then
            log "⚠️  sesman died! Restarting..."
            /usr/sbin/xrdp-sesman --nodaemon &
        fi
        sleep 5
    done
}

# Start xrdp
start_xrdp() {
    log "Starting xrdp on port 3389..."
    
    # Check if xrdp is already running
    if pgrep -x "xrdp" > /dev/null; then
        log "xrdp already running, killing it..."
        pkill xrdp
        sleep 2
    fi
    
    log "=========================================="
    log "XRDP is ready!"
    log "Connect to: localhost:3389"
    log "Username: xrdpuser"
    log "Password: ja908070"
    log "=========================================="
    
    # Start xrdp in foreground
    exec /usr/sbin/xrdp --nodaemon
}

# Main execution
main() {
    log "=========================================="
    log "Initializing XRDP Container"
    log "=========================================="
    
    # Run cleanup
    cleanup
    
    # Setup everything
    setup_dirs
    setup_pulse
    
    # Start services
    start_services
    
    # Start sesman
    start_sesman || {
        log "✗ Failed to start sesman with standard method"
        log "Trying alternative method..."
        /usr/sbin/xrdp-sesman --nodaemon --debug &
        sleep 5
    }
    
    # Start monitor in background
    monitor_sesman &
    
    # Start xrdp
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

# If xrdp fails, keep container alive
log "XRDP exited unexpectedly. Keeping container alive..."
while true; do
    sleep 60
done
