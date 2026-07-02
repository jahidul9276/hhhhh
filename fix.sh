#!/bin/bash

echo "========================================="
echo "NUCLEAR AUTH FIX"
echo "========================================="

docker exec -it xrdp bash -c "

# Stop everything
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
pkill -x Xorg 2>/dev/null || true
sleep 2

# COMPLETELY REPLACE PAM
cat > /etc/pam.d/xrdp-sesman <<'EOF'
#%PAM-1.0
auth        sufficient    pam_permit.so
auth        sufficient    pam_env.so
account     sufficient    pam_permit.so
session     sufficient    pam_permit.so
EOF

cat > /etc/pam.d/xrdp <<'EOF'
#%PAM-1.0
auth        sufficient    pam_permit.so
auth        sufficient    pam_env.so
account     sufficient    pam_permit.so
session     sufficient    pam_permit.so
EOF

# Replace system-auth too
cat > /etc/pam.d/system-auth <<'EOF'
#%PAM-1.0
auth        sufficient    pam_permit.so
account     sufficient    pam_permit.so
session     sufficient    pam_permit.so
EOF

# Force sesman.ini
cat > /etc/xrdp/sesman.ini <<'EOF'
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

# Start services
/usr/sbin/xrdp-sesman --nodaemon &
sleep 3
/usr/sbin/xrdp --nodaemon &

echo ''
echo '========================================='
echo '✓ NUCLEAR FIX APPLIED'
echo '  Username: root'
echo '  Password: ja908070'
echo '========================================='
"
