FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt update && apt install -y \
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
    policykit-1 \
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
    ca-certificates \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*


# Check GLIBC
RUN ldd --version


# Root password
RUN echo "root:ja908070" | chpasswd


# X11
RUN mkdir -p /etc/X11 && \
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config


# XFCE
RUN echo "startxfce4" > /root/.xsession


# DBUS
RUN mkdir -p /var/run/dbus && \
dbus-uuidgen > /var/lib/dbus/machine-id


# XRDP
RUN sed -i 's/crypt_level=high/crypt_level=low/' /etc/xrdp/xrdp.ini && \
sed -i 's/security_layer=negotiate/security_layer=rdp/' /etc/xrdp/xrdp.ini


RUN echo "exec startxfce4" > /etc/xrdp/startwm.sh && \
chmod +x /etc/xrdp/startwm.sh


RUN adduser xrdp ssl-cert


# Pulse
RUN mkdir -p /etc/pulse && \
cat > /etc/pulse/client.conf <<EOF
default-server = unix:/run/pulse/native
autospawn = no
daemon-binary = /bin/true
EOF


COPY start.sh /start.sh
RUN chmod +x /start.sh


EXPOSE 3389

CMD ["/start.sh"]
