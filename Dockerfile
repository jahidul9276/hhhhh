FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Add i386 architecture for 32-bit Wine support
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
polkitd \
pkexec \
pulseaudio \
pulseaudio-utils \
firefox-esr \
firejail \
python3 \
python3-pip \
python3-venv \
build-essential \
ca-certificates \
wine \
wine32 \
libc6:i386 \
procps \
iputils-ping \
telnet \
vim \
htop \
apt-utils \
xauth \
xorg \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Set root password
RUN echo "root:ja908070" | chpasswd

# Create X11 configuration
RUN mkdir -p /etc/X11
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Set default X session
RUN echo "xfce4-session" > /root/.xsession

# Create xrdp startup script
RUN cat >/etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/0
exec startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Create necessary directories
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/user/0 /run/xrdp /run/xrdp/sockdir /var/log/xrdp
RUN chmod 755 /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/xrdp /run/xrdp/sockdir /var/log/xrdp
RUN chmod 1777 /tmp

# Copy configuration files
COPY pulse-client.conf /etc/pulse/client.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Set working directory
WORKDIR /root

# Expose RDP port
EXPOSE 3389

# Start script
CMD ["/start.sh"]
