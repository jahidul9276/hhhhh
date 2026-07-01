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
software-properties-common \
apt-utils \
systemd \
systemd-sysv \
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
exec startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Configure xrdp
RUN sed -i 's/^#.*port=3389/port=3389/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*use_vsock=.*/use_vsock=false/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*crypt_level=.*/crypt_level=low/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^#.*ssl_protocols=.*/ssl_protocols=TLSv1.2,TLSv1.3/g' /etc/xrdp/xrdp.ini

# Create necessary directories
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/user/0
RUN chmod 755 /var/run/xrdp /var/run/xrdp-sesman /run/dbus

# Create .Xauthority file
RUN touch /root/.Xauthority && chmod 600 /root/.Xauthority

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
