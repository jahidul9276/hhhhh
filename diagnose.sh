#!/bin/bash

echo "========================================="
echo "XRDP Authorization Diagnostic"
echo "========================================="

CONTAINER="xrdp"

echo ""
echo "1. Check [Security] section of sesman.ini (this is what actually gates root login):"
docker exec "$CONTAINER" awk '/^\[Security\]/{f=1} /^\[.*\]/{if($0!~/Security/)f=0} f' /etc/xrdp/sesman.ini

echo ""
echo "2. Warn if AllowRootLogin exists OUTSIDE [Security] (it will be silently ignored there):"
docker exec "$CONTAINER" awk '
  /^\[/{sec=$0}
  /AllowRootLogin/{ if (sec !~ /Security/) print "  ⚠ Found in " sec " — this instance is IGNORED by xrdp-sesman"; else print "  ✓ Found in " sec }
' /etc/xrdp/sesman.ini

echo ""
echo "3. Check xrdp.ini root/console flags:"
docker exec "$CONTAINER" grep -E "allow_root|allow_console|disable_root_login" /etc/xrdp/xrdp.ini

echo ""
echo "4. Check sesman log for authorization errors:"
docker exec "$CONTAINER" tail -30 /var/log/xrdp-sesman.log 2>/dev/null | grep -i "authoriz\|allow\|root" || echo "No log or no matching lines"

echo ""
echo "5. Check xrdp log:"
docker exec "$CONTAINER" tail -30 /var/log/xrdp.log 2>/dev/null | grep -i "authoriz\|allow\|root" || echo "No log or no matching lines"

echo ""
echo "6. Check running services:"
docker exec "$CONTAINER" ps aux | grep -E "xrdp|sesman" | grep -v grep

echo ""
echo "========================================="
echo "If AllowRootLogin shows up outside [Security] above, fix sesman.ini and:"
echo "  docker restart $CONTAINER"
echo "========================================="
