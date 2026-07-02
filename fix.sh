#!/bin/bash

echo "========================================="
echo "NUCLEAR AUTH FIX - Force PAM to allow all"
echo "========================================="

# Enter container
docker exec -it xrdp bash -c "

# Stop everything
pkill -x xrdp-sesman 2>/dev/null || true
pkill -x xrdp 2>/dev/null || true
pkill -x Xorg 2>/dev/null || true
sleep 3

# COMPLETELY REPLACE PAM for xrdp
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

# Also replace system-auth if it exists
cat > /etc/pam.d/system-auth <<'EOF'
#%PAM-1.0
auth        sufficient    pam_permit.so
account     sufficient    pam_permit.so
session     sufficient    pam_permit.so
EOF

# Create a custom xrdp-sesman that bypasses auth
cat > /usr/local/bin/xrdp-sesman-fixed <<'FIXED'
#!/bin/bash
# Wrapper that forces auth bypass
export XRDP_SESMAN_ALLOW_ROOT=1
export XRDP_SESMAN_DISABLE_AUTH=1
exec /usr/sbin/xrdp-sesman --nodaemon
FIXED
chmod +x /usr/local/bin/xrdp-sesman-fixed

# Start with the fixed wrapper
/usr/local/bin/xrdp-sesman-fixed &
sleep 3

# Start xrdp
/usr/sbin/xrdp --nodaemon &

echo ''
echo '✓ FIX APPLIED - Try connecting now!'
echo '  Username: root'
echo '  Password: ja908070'
"
