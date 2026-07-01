FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt-get update && \
    apt-get install -y \
    libc6 \
    libc6:i386 \
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
    polkitd \
    pkexec \
    pulseaudio \
    pulseaudio-utils \
    wine \
    wine32 \
    firefox-esr \
    firejail \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Show GLIBC version
RUN ldd --version

# Root password
RUN echo "root:ja908070" | chpasswd

# X11
RUN mkdir -p /etc/X11 && \
    echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# XFCE session
RUN echo "startxfce4" > /root/.xsession && \
    chmod 700 /root/.xsession

# DBUS
RUN mkdir -p /run/dbus /var/lib/dbus && \
    dbus-uuidgen > /var/lib/dbus/machine-id

# XRDP
RUN sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini && \
    sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini && \
    printf '#!/bin/sh\nexec startxfce4\n' > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

RUN adduser xrdp ssl-cert

# PulseAudio client
RUN mkdir -p /etc/pulse && \
    printf 'default-server = unix:/run/pulse/native\nautospawn = no\ndaemon-binary = /bin/true\n' > /etc/pulse/client.conf

COPY start.sh /start.sh

RUN chmod +x /start.sh

EXPOSE 3389

CMD ["/start.sh"]
