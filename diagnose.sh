#!/bin/bash

echo "========================================="
echo "XRDP Authorization Diagnostic"
echo "========================================="

CONTAINER="xrdp"

echo ""
echo "1. Check sesman configuration:"
docker exec $CONTAINER grep -E "AllowRootLogin|RootLoginAllowed|DisableAuthentication|AllowConsoleLogin" /etc/xrdp/sesman.ini

echo ""
echo "2. Check xrdp configuration:"
docker exec $CONTAINER grep -E "allow_root|allow_console|disable_root_login" /etc/xrdp/xrdp.ini

echo ""
echo "3. Check sesman log for authorization errors:"
docker exec $CONTAINER tail -20 /var/log/xrdp-sesman.log 2>/dev/null | grep -i "authoriz\|allow\|root" || echo "No log or no errors"

echo ""
echo "4. Check xrdp log:"
docker exec $CONTAINER tail -20 /var/log/xrdp.log 2>/dev/null | grep -i "authoriz\|allow\|root" || echo "No log or no errors"

echo ""
echo "5. Check running services:"
docker exec $CONTAINER ps aux | grep -E "xrdp|sesman"

echo ""
echo "6. Test authorization fix:"
docker exec $CONTAINER /fix-auth.sh

echo ""
echo "========================================="
echo "Restart container after diagnostics:"
echo "docker restart $CONTAINER"
echo "========================================="
