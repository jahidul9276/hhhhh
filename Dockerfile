FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Add i386 architecture
RUN dpkg --add-architecture i386

# Install required packages
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
pulseaudio \
pulseaudio-utils \
firefox-esr \
python3 \
python3-pip \
build-essential \
ca-certificates \
wine \
wine32 \
libc6:i386 \
procps \
xauth \
xorg \
polkitd \
pkexec \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash xrdpuser && \
    echo "xrdpuser:ja908070" | chpasswd && \
    usermod -aG sudo xrdpuser

# Set root password (for emergency)
RUN echo "root:ja908070" | chpasswd

# Create X11 configuration
RUN mkdir -p /etc/X11
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Set default X session for user
RUN mkdir -p /home/xrdpuser/.config/xfce4 && \
    echo "xfce4-session" > /home/xrdpuser/.xsession && \
    chown -R xrdpuser:xrdpuser /home/xrdpuser

# Create xrdp startup script
RUN cat >/etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
export HOME=/home/xrdpuser
export SHELL=/bin/bash
exec startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Configure xrdp
RUN sed -i 's/^port=.*/port=3389/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^use_vsock=.*/use_vsock=false/g' /etc/xrdp/xrdp.ini
RUN sed -i 's/^crypt_level=.*/crypt_level=low/g' /etc/xrdp/xrdp.ini

# Allow root login (just in case)
RUN sed -i 's/^AllowRootLogin=.*/AllowRootLogin=true/g' /etc/xrdp/sesman.ini || \
    echo "AllowRootLogin=true" >> /etc/xrdp/sesman.ini

# Create necessary directories
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/user/1000
RUN chmod 755 /var/run/xrdp /var/run/xrdp-sesman /run/dbus
RUN chmod 755 /run/user/1000

# Create .Xauthority for user
RUN touch /home/xrdpuser/.Xauthority && \
    chown xrdpuser:xrdpuser /home/xrdpuser/.Xauthority && \
    chmod 600 /home/xrdpuser/.Xauthority

# Copy start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389

CMD ["/start.sh"]
