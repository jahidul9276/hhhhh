version: '3.8'
services:
  xrdp:
    build: .
    container_name: xrdp
    privileged: true
    ports:
      - "3389:3389"
    restart: unless-stopped
    environment:
      - DISPLAY=:0
      - XDG_RUNTIME_DIR=/run/user/0
      - PULSE_SERVER=unix:/run/pulse/native
    volumes:
      # Mount X11 socket
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      # Mount pulse audio socket (if available)
      - /run/user/1000/pulse:/run/pulse/host:ro
      # Mount for persistent data
      - xrdp-data:/var/lib/xrdp
      - dbus-data:/run/dbus
      - pulse-data:/run/pulse
    cap_add:
      - SYS_ADMIN
      - DAC_READ_SEARCH
      - NET_ADMIN
      - IPC_LOCK
      - SYS_CHROOT
      - SETUID
      - SETGID
    security_opt:
      - apparmor:unconfined
      - seccomp=unconfined
    devices:
      - /dev/snd:/dev/snd:rw  # For audio
      - /dev/dri:/dev/dri:rw  # For GPU acceleration
    tmpfs:
      - /run:exec
      - /tmp:exec
    healthcheck:
      test: ["CMD", "pgrep", "xrdp"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

volumes:
  xrdp-data:
  dbus-data:
  pulse-data:
