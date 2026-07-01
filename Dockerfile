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
iproute2 \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash xrdpuser && \
    echo "xrdpuser:ja908070" | chpasswd && \
    usermod -aG sudo xrdpuser

# Set root password
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

# Create complete xrdp configuration
RUN cat > /etc/xrdp/xrdp.ini <<'EOF'
[Globals]
ini_version=1
fork=true
port=3389
use_vsock=false
crypt_level=low
channel_code=1
max_bpp=32
xserverbpp=24
ssl_protocols=TLSv1.2,TLSv1.3
ssl_ciphers=HIGH
enable_fuse=true
fuse_mount_name=thinclient_drives
fuse_mount_path=/tmp/fuse_mount
fuse_allow_other=true
tcp_send_buffer_bytes=32768
tcp_recv_buffer_bytes=32768

[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20

[Xvnc]
name=Xvnc
lib=libvnc.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=1

[XRDP]
name=XRDP
lib=libxrdp.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=10

[Chansrv]
name=Chansrv
lib=libxrdpchansrv.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=3
EOF

# Create sesman configuration
RUN cat > /etc/xrdp/sesman.ini <<'EOF'
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=true
UserWindowManager=startxfce4
DefaultWindowManager=startxfce4
MaxSessions=10
MaxDisconnections=10
SessionTimeout=0

[Xorg]
param=Xorg
param=-config
param=xrdp/xorg.conf
param=-noreset
param=-nolisten
param=tcp
param=-logfile
param=.xorgxrdp.%s.log

[Xvnc]
param=Xvnc
param=-bs
param=-auth
param=.Xauthority
param=-geometry
param=%%GEOMETRY%%
param=-depth
param=%%COLORDEPTH%%
param=-rfbauth
param=.vncpasswd
param=-localhost
param=-dpi
param=%%DPI%%

[Chansrv]
param=chansrv
param=-audio
param=-videofifo
param=/tmp/xrdp-video-fifo
param=-videopidfifo
param=/tmp/xrdp-video-pid-fifo

[SessionVariables]
X11DisplayOffset=10
MaxDisplayNumber=10
AllowRootLogin=true
AllowConsole=true
EnableUserWindowManager=true
UserWindowManager=startxfce4
DefaultWindowManager=startxfce4
FuseMountName=thinclient_drives
FuseMountPath=/tmp/fuse_mount
KillDisconnected=false
DisconnectedTimeLimit=0
IdleTimeLimit=0
Policy=Default
EOF

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
