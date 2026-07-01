#!/bin/bash

set -e

echo "=========================================="
echo "XRDP Container Starting..."
echo "=========================================="

# Function to check if process is running
is_running() {
    pgrep -x "$1" > /dev/null 2>&1
}

# Setup proper permissions
setup_permissions() {
    echo "Setting up proper permissions..."
    
    # Create necessary directories
    mkdir -p /run/dbus /var/run/dbus /tmp/.X11-unix /run/user/0
    mkdir -p /var/run/xrdp /var/run/xrdp-sesman
    
    # Set proper permissions
    chmod 1777 /tmp/.X11-unix
    chmod 755 /run/dbus /var/run/dbus
    chmod 755 /var/run/xrdp /var/run/xrdp-sesman
    
    # Create pulse cookie directory
    mkdir -p /root/.config/pulse
    touch /root/.config/pulse/cookie
    chmod 600 /root/.config/pulse/cookie
}

# Start D-Bus
start_dbus() {
    echo "Starting D-Bus daemon..."
    
    # Kill existing dbus if any
    pkill dbus-daemon 2>/dev/null || true
    
    # Start dbus
    if [ -f /run/dbus/pid ]; then
        rm -f /run/dbus/pid
    fi
    
    dbus-daemon --system --fork --print-pid 2>/dev/null || \
    dbus-daemon --system --fork
    
    sleep 2
    echo "D-Bus started successfully"
}

# Start PulseAudio
start_pulseaudio() {
    echo "Starting PulseAudio..."
    
    # Kill existing pulseaudio
    pkill pulseaudio 2>/dev/null || true
    
    # Wait for process to die
    sleep 2
    
    # Start pulseaudio as system daemon
    pulseaudio --start --daemonize --system \
        --exit-idle-time=-1 \
        --realtime \
        --log-level=1 \
        2>/dev/null || \
    pulseaudio --start --daemonize --system --exit-idle-time=-1 2>/dev/null || \
    pulseaudio --start --daemonize
    
    sleep 2
    
    # Check if pulseaudio is running
    if is_running pulseaudio; then
        echo "PulseAudio started successfully"
    else
        echo "Warning: PulseAudio failed to start"
    fi
}

# Start XRDP session manager
start_xrdp_sesman() {
    echo "Starting XRDP session manager..."
    
    # Kill existing xrdp-sesman
    pkill xrdp-sesman 2>/dev/null || true
    sleep 1
    
    # Start xrdp-sesman in background
    /usr/sbin/xrdp-sesman --nodaemon &
    XRDP_SESMAN_PID=$!
    
    sleep 3
    
    # Check if xrdp-sesman is running
    if is_running xrdp-sesman; then
        echo "XRDP session manager started (PID: $XRDP_SESMAN_PID)"
    else
        echo "Error: XRDP session manager failed to start"
        exit 1
    fi
}

# Start XRDP
start_xrdp() {
    echo "Starting XRDP server..."
    
    # Kill existing xrdp
    pkill xrdp 2>/dev/null || true
    sleep 1
    
    # Start xrdp in foreground
    /usr/sbin/xrdp --nodaemon
}

# Main execution
main() {
    # Setup permissions first
    setup_permissions
    
    # Mount /proc and /sys with proper permissions if needed
    mount -t proc proc /proc -o remount,rw 2>/dev/null || true
    mount -t sysfs sys /sys -o remount,rw 2>/dev/null || true
    
    # Start services in correct order
    start_dbus
    start_pulseaudio
    start_xrdp_sesman
    
    # Create .Xauthority if it doesn't exist
    if [ ! -f /root/.Xauthority ]; then
        touch /root/.Xauthority
        chmod 600 /root/.Xauthority
    fi
    
    # Start XRDP (this will run in foreground)
    start_xrdp
}

# Trap signals
trap 'echo "Stopping XRDP services..."; pkill xrdp; pkill xrdp-sesman; pkill pulseaudio; pkill dbus-daemon; exit 0' SIGTERM SIGINT

# Run main function
main

# If xrdp fails, keep container alive for debugging
echo "XRDP exited. Keeping container alive for debugging..."
while true; do
    sleep 60
done
