#!/usr/bin/env bash
set -e
: "${VPS_USER:=Mikasa}"
: "${VPS_PASS:?VPS_PASS must be set}"

if ! id "$VPS_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$VPS_USER"
  usermod -aG sudo "$VPS_USER"
fi
echo "$VPS_USER:$VPS_PASS" | chpasswd

HOME_DIR=$(getent passwd "$VPS_USER" | cut -d: -f6)
mkdir -p "$HOME_DIR/.vnc"
echo "$VPS_PASS" | vncpasswd -f > "$HOME_DIR/.vnc/passwd"
chmod 600 "$HOME_DIR/.vnc/passwd"
cat > "$HOME_DIR/.vnc/xstartup" <<'XS'
#!/bin/sh
unset SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS
exec startxfce4
XS
chmod +x "$HOME_DIR/.vnc/xstartup"
chown -R "$VPS_USER:$VPS_USER" "$HOME_DIR"

service ssh start
su - "$VPS_USER" -c "vncserver :1 -geometry 1600x900 -depth 24 -localhost no"
echo ">> Web desktop: http://localhost:6080/vnc.html   user=$VPS_USER"
exec websockify --web=/usr/share/novnc 0.0.0.0:6080 localhost:5901
