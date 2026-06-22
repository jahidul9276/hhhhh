FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

# Add i386 architecture for Wine
RUN dpkg --add-architecture i386

# Install required packages
RUN apt update && apt install -y \
    xrdp \
    xfce4 \
    xfce4-goodies \
    xorg \
    dbus-x11 \
    sudo \
    curl \
    wget \
    nano \
    net-tools \
    policykit-1 \
    pulseaudio \
    pulseaudio-utils \
    wine \
    wine32 \
    firefox-esr \
    python3 \
    python3-pip \
    && apt clean && rm -rf /var/lib/apt/lists/*

# Set root password
RUN echo "root:ja908070" | chpasswd

# Configure X11
RUN sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config || echo "allowed_users=anybody" >> /etc/X11/Xwrapper.config

# Set XFCE as default session
RUN echo "startxfce4" > /root/.xsession && chmod 700 /root/.xsession

# Generate machine-id for dbus
RUN dbus-uuidgen > /var/lib/dbus/machine-id

# Configure xrdp
RUN sed -i 's/crypt_level=high/crypt_level=low/' /etc/xrdp/xrdp.ini && \
    sed -i 's/security_layer=negotiate/security_layer=rdp/' /etc/xrdp/xrdp.ini && \
    echo "startxfce4" > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

# Add xrdp to ssl-cert group
RUN adduser xrdp ssl-cert

# Create PulseAudio config directory and file
RUN mkdir -p /etc/pulse && \
    echo "default-server = unix:/run/pulse/native" > /etc/pulse/client.conf && \
    echo "autospawn = no" >> /etc/pulse/client.conf && \
    echo "daemon-binary = /bin/true" >> /etc/pulse/client.conf

# Copy and setup start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389

CMD ["/start.sh"]
