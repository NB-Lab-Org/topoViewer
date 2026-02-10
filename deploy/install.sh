#!/bin/bash
# install.sh - TopoViewer Installation Script
#
# Installs TopoViewer from the dist/ package to /opt/topoviewer/
# and sets up systemd service and management scripts.
#
# Usage:
#   ./install.sh                          # Install with defaults
#   ALLOWED_HOSTNAMES=localhost,my.domain ./install.sh  # Install with custom hostnames

set -e

INSTALL_DIR="/opt/topoviewer"
SERVICE_FILE="/etc/systemd/system/topoviewer.service"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing TopoViewer to ${INSTALL_DIR}..."

# Create directory structure
mkdir -p "${INSTALL_DIR}"/{bin,config,html-public,logs}

# Skip copy if already running from the install directory (e.g., called by get.sh)
if [ "$(realpath "${SCRIPT_DIR}")" != "$(realpath "${INSTALL_DIR}")" ]; then
    # Copy binary and assets (supports both dist/ and repo layouts)
    for item in topoviewer html-static html-public config html-template; do
        if [ -e "${SCRIPT_DIR}/../dist/${item}" ]; then
            cp -r "${SCRIPT_DIR}/../dist/${item}" "${INSTALL_DIR}/"
        elif [ -e "${SCRIPT_DIR}/${item}" ]; then
            cp -r "${SCRIPT_DIR}/${item}" "${INSTALL_DIR}/"
        fi
    done

    # Install switch script
    if [ -f "${SCRIPT_DIR}/bin/switch-topoviewer.sh" ]; then
        cp "${SCRIPT_DIR}/bin/switch-topoviewer.sh" "${INSTALL_DIR}/bin/"
    elif [ -f "${SCRIPT_DIR}/../deploy/bin/switch-topoviewer.sh" ]; then
        cp "${SCRIPT_DIR}/../deploy/bin/switch-topoviewer.sh" "${INSTALL_DIR}/bin/"
    fi
fi
chmod +x "${INSTALL_DIR}/bin/switch-topoviewer.sh" 2>/dev/null || true
chmod +x "${INSTALL_DIR}/topoviewer" 2>/dev/null || true

# Install systemd service
if [ -f "${SCRIPT_DIR}/systemd/topoviewer.service" ]; then
    cp "${SCRIPT_DIR}/systemd/topoviewer.service" "${SERVICE_FILE}"
elif [ -f "${SCRIPT_DIR}/../deploy/systemd/topoviewer.service" ]; then
    cp "${SCRIPT_DIR}/../deploy/systemd/topoviewer.service" "${SERVICE_FILE}"
fi

# Create initial environment file if it doesn't exist
if [ ! -f "${INSTALL_DIR}/config/current-topology.env" ]; then
    cat > "${INSTALL_DIR}/config/current-topology.env" << 'EOF'
# TopoViewer Configuration
# TOPOLOGY_PATH: Set by switch-topoviewer.sh or manually
# ALLOWED_HOSTNAMES: Comma-separated list of hostnames for CORS
TOPOLOGY_PATH=
ALLOWED_HOSTNAMES=localhost
EOF
    echo "Created initial config at ${INSTALL_DIR}/config/current-topology.env"
    echo "  Edit ALLOWED_HOSTNAMES to add your domain (e.g., localhost,my.domain.com)"
fi

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable topoviewer

echo ""
echo "TopoViewer installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Edit ${INSTALL_DIR}/config/current-topology.env"
echo "     - Set ALLOWED_HOSTNAMES to your domain"
echo "     - Set TOPOLOGY_PATH or use switch-topoviewer.sh"
echo "  2. Start the service: systemctl start topoviewer"
echo "  3. Switch topology:   ${INSTALL_DIR}/bin/switch-topoviewer.sh switch <name>"
