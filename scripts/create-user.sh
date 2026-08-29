#!/bin/bash
# FreeVPS Mark1.3 - Quick User Creator
# Creates Mikasa user with Eren@Home$123

set -e

USER_LOWER="mikasa"
USER_CAP="Mikasa"
PASS='Eren@Home$123'

echo "Creating VPS user: $USER_CAP / $USER_LOWER"

# Check root
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

# Create lowercase (primary)
if id "$USER_LOWER" &>/dev/null; then
  echo "User $USER_LOWER already exists"
else
  $SUDO useradd -m -s /bin/bash "$USER_LOWER"
  echo "Created $USER_LOWER"
fi

echo "$USER_LOWER:$PASS" | $SUDO chpasswd
$SUDO usermod -aG sudo "$USER_LOWER" 2>/dev/null || $SUDO usermod -aG wheel "$USER_LOWER" 2>/dev/null || true
echo "$USER_LOWER ALL=(ALL) NOPASSWD:ALL" | $SUDO tee /etc/sudoers.d/$USER_LOWER > /dev/null
$SUDO chmod 440 /etc/sudoers.d/$USER_LOWER

# Try capital
if ! id "$USER_CAP" &>/dev/null; then
  $SUDO useradd -m -s /bin/bash "$USER_CAP" 2>/dev/null && echo "Created $USER_CAP" || echo "Capital username not allowed, using $USER_LOWER as primary (login with Mikasa still works on dashboard)"
fi

if id "$USER_CAP" &>/dev/null; then
  echo "$USER_CAP:$PASS" | $SUDO chpasswd 2>/dev/null || true
  $SUDO usermod -aG sudo "$USER_CAP" 2>/dev/null || true
fi

echo ""
echo "✅ Users ready:"
echo "  Username: Mikasa (dashboard) / mikasa (system)"
echo "  Password: $PASS"
echo ""
echo "Test login:"
echo "  su - mikasa"
echo "  Password: $PASS"
echo ""
id $USER_LOWER
