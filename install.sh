#!/bin/bash

# OpenTunnel Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/julianponguta/opentunnel/main/install.sh | sudo bash

echo "[*] OpenTunnel Installer"

# Add to /etc/profile.d/ for all users
echo "[*] Installing ot command..."

cat > /etc/profile.d/ot.sh << 'EOF'
ot() {
    curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"
}
EOF

chmod +x /etc/profile.d/ot.sh

# Also add to root's .bashrc for immediate use
if ! grep -q "ot()" /root/.bashrc 2>/dev/null; then
    echo 'ot() { curl -fsSL "https://raw.githubusercontent.com/julianponguta/opentunnel/main/connect.sh?v=$(date +%s)" | sudo bash -s -- "${@}"; }' >> /root/.bashrc
fi

echo "[+] OpenTunnel installed!"
echo ""
echo "Usage:"
echo "  ot              # 60 min, tunneluser"
echo "  ot root         # 60 min, root"
echo "  ot 30 root      # 30 min, root"
echo ""
echo "Start using: ot root"
