FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

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
    build-essential \
    wget \
    libssl-dev \
    zlib1g-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libgdbm-dev \
    libbz2-dev \
    libffi-dev \
    liblzma-dev \
    tk-dev \
    uuid-dev \
    ca-certificates \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*


# Install Python 3.10
RUN cd /tmp && \
    wget https://www.python.org/ftp/python/3.10.13/Python-3.10.13.tgz && \
    tar -xf Python-3.10.13.tgz && \
    cd Python-3.10.13 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && \
    make altinstall && \
    ln -s /usr/local/bin/python3.10 /usr/bin/python3 && \
    ln -s /usr/local/bin/pip3.10 /usr/bin/pip3 && \
    cd / && rm -rf /tmp/*


# Root password
RUN echo "root:ja908070" | chpasswd


# X11 fix
RUN mkdir -p /etc/X11 && \
    echo "allowed_users=anybody" > /etc/X11/Xwrapper.config


# XFCE session
RUN echo "startxfce4" > /root/.xsession && \
    chmod 700 /root/.xsession


# dbus machine id
RUN mkdir -p /var/run/dbus && \
    dbus-uuidgen > /var/lib/dbus/machine-id


# XRDP config
RUN sed -i 's/crypt_level=high/crypt_level=low/' /etc/xrdp/xrdp.ini && \
    sed -i 's/security_layer=negotiate/security_layer=rdp/' /etc/xrdp/xrdp.ini


RUN echo "exec startxfce4" > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh


RUN adduser xrdp ssl-cert


# Pulse config
RUN mkdir -p /etc/pulse && \
echo "\
default-server = unix:/run/pulse/native
autospawn = no
daemon-binary = /bin/true
" > /etc/pulse/client.conf


COPY start.sh /start.sh
RUN chmod +x /start.sh


EXPOSE 3389


CMD ["/start.sh"]
