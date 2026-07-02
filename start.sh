#!/bin/bash

echo "========================================="
echo "XRDP Container Debug Tool"
echo "========================================="

CONTAINER_NAME="xrdp"

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container ${CONTAINER_NAME} is not running"
    echo "Starting container..."
    docker-compose up -d
    sleep 5
fi

echo ""
echo "1. Container Status:"
docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "2. Running Processes:"
docker exec ${CONTAINER_NAME} ps aux | grep -E "xrdp|Xorg|xfce|dbus|pulse|bash"

echo ""
echo "3. Mount Points:"
docker exec ${CONTAINER_NAME} mount | grep -E "proc|sys|dev|tmpfs"

echo ""
echo "4. Namespace Information:"
docker exec ${CONTAINER_NAME} ls -la /proc/self/ns/

echo ""
echo "5. XRDP Logs:"
docker exec ${CONTAINER_NAME} tail -30 /var/log/xrdp.log 2>/dev/null || echo "No xrdp.log found"

echo ""
echo "6. Sesman Logs:"
docker exec ${CONTAINER_NAME} tail -30 /var/log/xrdp-sesman.log 2>/dev/null || echo "No sesman.log found"

echo ""
echo "7. Xorg Logs:"
docker exec ${CONTAINER_NAME} ls -la /var/log/ | grep Xorg
docker exec ${CONTAINER_NAME} tail -20 /var/log/Xorg.*.log 2>/dev/null || echo "No Xorg logs found"

echo ""
echo "8. Display Sockets:"
docker exec ${CONTAINER_NAME} ls -la /tmp/.X11-unix/

echo ""
echo "9. Xauthority:"
docker exec ${CONTAINER_NAME} ls -la /root/.Xauthority

echo ""
echo "10. Runtime Directory:"
docker exec ${CONTAINER_NAME} ls -la /run/user/0/

echo ""
echo "11. PulseAudio Status:"
docker exec ${CONTAINER_NAME} ps aux | grep pulseaudio
docker exec ${CONTAINER_NAME} ls -la /run/pulse/

echo ""
echo "12. DBus Status:"
docker exec ${CONTAINER_NAME} ps aux | grep dbus
docker exec ${CONTAINER_NAME} ls -la /run/dbus/

echo ""
echo "13. Network Ports:"
docker exec ${CONTAINER_NAME} netstat -tulpn | grep 3389

echo ""
echo "14. System Resources:"
docker exec ${CONTAINER_NAME} free -h
docker exec ${CONTAINER_NAME} df -h
docker exec ${CONTAINER_NAME} nproc

echo ""
echo "15. Test RDP Connection:"
nc -zv localhost 3389 2>&1 || echo "❌ Port 3389 not accessible"

echo ""
echo "========================================="
echo "Debug Complete"
echo "========================================="
echo ""
echo "To fix common issues:"
echo "  docker restart ${CONTAINER_NAME}"
echo "  docker logs -f ${CONTAINER_NAME}"
echo "  docker exec ${CONTAINER_NAME} tail -f /var/log/xrdp.log"
