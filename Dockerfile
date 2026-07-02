FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Add i386 architecture for 32-bit support
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
pulseaudio \
pulseaudio-utils \
firefox-esr \
python3 \
python3-pip \
python3-venv \
build-essential \
ca-certificates \
wine \
wine32 \
libc6:i386 \
procps \
iproute2 \
x11-utils \
xauth \
pm-utils \
xserver-xorg-video-dummy \
xserver-xorg-core \
x11-xserver-utils \
xorg \
xvfb \
x11vnc \
openssh-server \
dnsutils \
iputils-ping \
telnet \
ltrace \
strace \
openssl \
pamix \
libpam-modules \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Create a non-root user with sudo privileges
RUN useradd -m -s /bin/bash xrdpuser && \
    echo "xrdpuser:ja908070" | chpasswd && \
    echo "xrdpuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set root password
RUN echo "root:ja908070" | chpasswd

# Create necessary directories with proper permissions
RUN mkdir -p /var/run/xrdp /var/run/xrdp-sesman /run/dbus /run/pulse /var/lib/xrdp /run/user/1000 /tmp/.X11-unix /var/log/xrdp
RUN chmod 1777 /tmp/.X11-unix
RUN chmod 700 /run/user/1000
RUN chmod 755 /var/run/xrdp /var/run/xrdp-sesman

# Create Xauthority files
RUN touch /root/.Xauthority /home/xrdpuser/.Xauthority && \
    chmod 600 /root/.Xauthority /home/xrdpuser/.Xauthority && \
    chown xrdpuser:xrdpuser /home/xrdpuser/.Xauthority

# Configure X11 wrapper
RUN mkdir -p /etc/X11
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# Set default session for both users
RUN echo "xfce4-session" > /root/.xsession
RUN echo "xfce4-session" > /home/xrdpuser/.xsession && \
    chown xrdpuser:xrdpuser /home/xrdpuser/.xsession

# CRITICAL: Create COMPLETE PAM configuration
RUN mkdir -p /etc/pam.d
RUN cat > /etc/pam.d/xrdp-sesman <<'PAMEOF'
#%PAM-1.0
auth        required      pam_permit.so
auth        required      pam_env.so
account     required      pam_permit.so
session     required      pam_permit.so
session     optional      pam_motd.so
PAMEOF

RUN cat > /etc/pam.d/xrdp <<'PAMEOF'
#%PAM-1.0
auth        required      pam_permit.so
auth        required      pam_env.so
account     required      pam_permit.so
session     required      pam_permit.so
PAMEOF

# CRITICAL: Create COMPLETE xrdp configuration
RUN cat > /etc/xrdp/xrdp.ini <<'EOF'
[Globals]
ini_version=1
fork=true
port=3389
use_vsock=false
tcp_nodelay=true
tcp_keepalive=true
security_layer=negotiate
crypt_level=low
max_bpp=16
xserverbpp=16
codecs=
allow_root=true
allow_console=true
enable_token_login=false
disable_root_login=false
rdp_ssl=yes
ssl_cert_file=/etc/xrdp/xrdp-cert.pem
ssl_key_file=/etc/xrdp/xrdp-key.pem
ssl_verify=no
rdp_use_ssl=yes
crypto_use_fips=false
tcp_send_buffer_bytes=262144
tcp_recv_buffer_bytes=262144
max_connections=100
rdp_enhanced_security=yes
tls_min_version=1.0
tls_max_version=1.3

[Xorg]
name=Xorg
lib=libxup.so
username=root
password=ja908070
ip=127.0.0.1
port=-1
xserverbpp=16
codecs=
security_layer=negotiate
crypt_level=low
max_bpp=16

[X11rdp]
name=X11rdp
lib=libxup.so
username=root
password=ja908070
ip=127.0.0.1
port=-1
xserverbpp=16
codecs=
security_layer=negotiate
crypt_level=low
max_bpp=16

[Chansrv]
name=Chansrv
lib=libchansrv.so
username=root
password=ja908070
ip=127.0.0.1
port=-1

[SessionVariables]
X11DisplayOffset=10
MaxDisplayNumber=50
KillDisconnected=false
IdleTimeLimit=0
DisconnectedTimeLimit=0
EOF

# Generate SSL certificates
RUN openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/xrdp-key.pem -out /etc/xrdp/xrdp-cert.pem -days 365 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    chmod 600 /etc/xrdp/xrdp-key.pem && \
    chmod 644 /etc/xrdp/xrdp-cert.pem

# Disable polkit for xrdp
RUN rm -f /etc/polkit-1/localauthority/50-local.d/*.pkla 2>/dev/null || true && \
    rm -f /etc/polkit-1/localauthority/10-vendor.d/*.pkla 2>/dev/null || true

RUN mkdir -p /etc/polkit-1/localauthority/50-local.d/
RUN cat > /etc/polkit-1/localauthority/50-local.d/99-xrdp.pkla <<'EOF'
[Allow xrdp]
Identity=unix-user:*
Action=*
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

# CRITICAL: Create sesman configuration with DisableAuthentication=true
RUN cat > /etc/xrdp/sesman.ini <<'EOF'
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=true
UserWindowManager=startwm.sh
DefaultWindowManager=startwm.sh
AllowRootLogin=true
AllowConsoleLogin=true
RootLoginAllowed=true
DisableAuthentication=true
EnableRemoteLogin=true
AlwaysGroupCheck=false
FuseMountName=thinclient_drives
SessionTimeout=0
DisconnectedTimeLimit=0
IdleTimeLimit=0
KillDisconnected=false
XDisplay=10
DisplayOffset=10
MaxDisplayNumber=50
UseXOrg=1
X11rdpPath=/usr/lib/xorg/Xorg

[X11rdp]
param=Xorg
param=-config
param=xrdp/xorg.conf
param=-noreset
param=-nolisten
param=tcp
param=-logfile
param=.xorgxrdp.%s.log

[Chansrv]
FuseMountName=thinclient_drives

[SessionVariables]
X11DisplayOffset=10
MaxDisplayNumber=50
KillDisconnected=false
IdleTimeLimit=0
DisconnectedTimeLimit=0
EOF

# Create Xorg configuration with proper video settings
RUN mkdir -p /etc/X11/xorg.conf.d
RUN cat > /etc/X11/xorg.conf.d/99-dummy.conf <<'EOF'
Section "Device"
    Identifier  "DummyDevice"
    Driver      "dummy"
    Option      "ConstantDPI" "true"
    Option      "NoDDC" "true"
    Option      "IgnoreEDID" "true"
    Option      "UseDisplayDevice" "none"
    Option      "NoRandR" "false"
    Option      "VideoRam" "262144"
EndSection

Section "Monitor"
    Identifier  "DummyMonitor"
    HorizSync   28-80
    VertRefresh 43-60
    Option      "DPMS" "false"
    Option      "Enable" "true"
    Option      "PreferredMode" "1280x720"
EndSection

Section "Screen"
    Identifier  "DummyScreen"
    Device      "DummyDevice"
    Monitor     "DummyMonitor"
    DefaultDepth 16
    SubSection "Display"
        Depth 16
        Modes "1280x720" "1024x768" "800x600"
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier  "DummyLayout"
    Screen      "DummyScreen"
    Option      "BlankTime" "0"
    Option      "StandbyTime" "0"
    Option      "SuspendTime" "0"
    Option      "OffTime" "0"
EndSection
EOF

# Create startwm.sh with proper Xorg startup
RUN cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
# XRDP startwm.sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export XDG_CURRENT_DESKTOP=XFCE
export XDG_MENU_PREFIX=xfce-
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share:/usr/local/share
export DISABLE_WAYLAND=1
export XDG_RUNTIME_DIR=/run/user/1000
export XAUTHORITY=/home/xrdpuser/.Xauthority
export HOME=/home/xrdpuser
export USER=xrdpuser
export SHELL=/bin/bash
export DISPLAY=:10
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Create runtime directory
mkdir -p /run/user/1000
chmod 700 /run/user/1000

# Clean up display locks
rm -f /tmp/.X0-lock /tmp/.X10-lock /tmp/.X11-unix/X0 /tmp/.X11-unix/X10

# Start DBus session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval `dbus-launch --sh-syntax --exit-with-session`
    export DBUS_SESSION_BUS_ADDRESS
fi

# Start XFCE with proper options
exec startxfce4 --display=:10
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# Remove light-locker and power manager
RUN apt-get remove -y light-locker xfce4-power-manager || true

# Disable screensaver and power management
RUN mkdir -p /home/xrdpuser/.config/xfce4/xfconf/xfce-perchannel-xml
RUN cat > /home/xrdpuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="blank-on-battery" type="int" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
  </property>
</channel>
EOF

RUN chown -R xrdpuser:xrdpuser /home/xrdpuser/.config

# Disable screensaver
RUN cat > /home/xrdpuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="enabled" type="bool" value="false"/>
  <property name="lock-enabled" type="bool" value="false"/>
</channel>
EOF

# Create pulse client configuration
RUN mkdir -p /etc/pulse
RUN cat > /etc/pulse/client.conf <<'EOF'
default-server = /run/pulse/native
autospawn = no
daemon-binary = /usr/bin/pulseaudio
extra-arguments = --exit-idle-time=-1 --disable-shm=yes --realtime=no
cookie-file = /home/xrdpuser/.config/pulse/cookie
enable-shm = no
disable-shm = yes
EOF

# Copy start.sh
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3389

CMD ["/start.sh"]
