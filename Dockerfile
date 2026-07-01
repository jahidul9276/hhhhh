FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

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
    libc6:i386 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "root:ja908070" | chpasswd

RUN mkdir -p /etc/X11
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

RUN echo "xfce4-session" > /root/.xsession

RUN cat >/etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

COPY pulse-client.conf /etc/pulse/client.conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389

CMD ["/start.sh"]
