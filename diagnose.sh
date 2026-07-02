#!/bin/bash

CONTAINER="xrdp"

echo "========================================="
echo "XRDP Authorization Diagnostic"
echo "========================================="

echo ""
echo "1. Check sesman configuration:"
docker exec $CONTAINER grep -E "AllowRootLogin|RootLoginAllowed|DisableAuthentication|AllowConsoleLogin" /etc/xrdp/sesman.ini

echo ""
echo "2. Check xrdp configuration:"
docker exec $CONTAINER grep -E "allow_root|allow_console|disable_root_login" /etc/xrdp/xrdp.ini

echo ""
echo "3. Check PAM configuration:"
docker exec $CONTAINER cat /etc/pam.d/xrdp-sesman

echo ""
echo "4. Check sesman log for authorization errors:"
docker exec $CONTAINER tail -50 /var/log/xrdp-sesman.log 2>/dev/null

echo ""
echo "5. Check xrdp log:"
docker exec $CONTAINER tail -50 /var/log/xrdp.log 2>/dev/null

echo ""
echo "6. Check running services:"
docker exec $CONTAINER ps aux | grep -E "xrdp|sesman"

echo ""
echo "7. Check users:"
docker exec $CONTAINER id root
docker exec $CONTAINER id xrdpuser

echo ""
echo "8. Check Xauthority files:"
docker exec $CONTAINER ls -la /root/.Xauthority /home/xrdpuser/.Xauthority 2>/dev/null

echo ""
echo "9. Check if port 3389 is listening:"
docker exec $CONTAINER netstat -tlnp | grep 3389

echo ""
echo "========================================="
echo "To restart container after fixes:"
echo "docker-compose restart"
echo "========================================="
