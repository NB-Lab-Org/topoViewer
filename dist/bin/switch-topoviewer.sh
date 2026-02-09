#!/bin/bash
# switch-topoviewer.sh - TopoViewer Topology Switching Tool
#
# Usage:
#   switch-topoviewer.sh switch <topology-name>  - Switch to a topology
#   switch-topoviewer.sh list                    - List available topologies
#   switch-topoviewer.sh current                 - Show current topology
#   switch-topoviewer.sh status                  - Show service status

set -e

# Configuration
CONTAINERLAB_DIR="/root/containerlab"
ENV_FILE="/opt/topoviewer/config/current-topology.env"
LOCK_FILE="/tmp/topoviewer-switch.lock"
SERVICE_NAME="topoviewer"

# Colors and formatting (for terminal, ignored by MCP)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Acquire lock to prevent concurrent operations
acquire_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        echo "❌ Error: Another switch operation is in progress"
        exit 1
    fi
}

# Release lock
release_lock() {
    flock -u 200 2>/dev/null || true
}

# Get current topology name from env file
get_current_topology() {
    if [ -f "$ENV_FILE" ]; then
        local path=$(grep "^TOPOLOGY_PATH=" "$ENV_FILE" | cut -d'=' -f2)
        if [ -n "$path" ]; then
            # Extract topology name from path
            basename "$(dirname "$path")"
        fi
    fi
}

# Check if a topology exists
topology_exists() {
    local name="$1"
    local topo_path="${CONTAINERLAB_DIR}/${name}/${name}.clab.yml"
    [ -f "$topo_path" ]
}

# Get topology file path
get_topology_path() {
    local name="$1"
    echo "${CONTAINERLAB_DIR}/${name}/${name}.clab.yml"
}

# Check if a topology is running in ContainerLab
topology_is_running() {
    local name="$1"
    containerlab inspect --all --format json 2>/dev/null | jq -e --arg name "$name" 'has($name)' >/dev/null 2>&1
}

# Command: switch
cmd_switch() {
    local topo_name="$1"

    if [ -z "$topo_name" ]; then
        echo "❌ Error: Topology name required"
        echo "   Usage: switch-topoviewer.sh switch <topology-name>"
        exit 1
    fi

    local topo_path=$(get_topology_path "$topo_name")

    # Check if topology file exists
    if ! topology_exists "$topo_name"; then
        echo "❌ Error: Topology file not found: $topo_name"
        echo "   Expected path: $topo_path"
        echo ""
        echo "   Use 'switch-topoviewer.sh list' to see available topologies"
        exit 1
    fi

    # Check if topology is running in ContainerLab
    if ! topology_is_running "$topo_name"; then
        echo "❌ Error: Topology is not running: $topo_name"
        echo "   The topology file exists but ContainerLab has not deployed it."
        echo ""
        echo "   Deploy the topology first:"
        echo "   containerlab deploy -t $topo_path"
        exit 1
    fi

    # Check if already on this topology
    local current=$(get_current_topology)
    if [ "$current" = "$topo_name" ]; then
        echo "ℹ️  Already on topology: $topo_name"
        echo "   Path: $topo_path"
        exit 0
    fi

    # Acquire lock
    acquire_lock
    trap release_lock EXIT

    echo "🔄 Switching to topology: $topo_name"

    # Update environment file
    echo "TOPOLOGY_PATH=$topo_path" > "$ENV_FILE"

    # Restart service
    systemctl daemon-reload
    systemctl restart "$SERVICE_NAME"

    # Wait for service to start and generate HTML files
    sleep 2

    # Verify service is running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "✅ Switched to topology: $topo_name"
        echo "   Path: $topo_path"
    else
        echo "❌ Error: TopoViewer failed to start"
        echo "   Check logs: journalctl -u $SERVICE_NAME -n 20"
        exit 1
    fi
}

# Command: list
cmd_list() {
    local current=$(get_current_topology)
    local running_count=0
    local total_count=0
    local running_topos=()
    local stopped_topos=()

    # Get running topologies from containerlab
    local running_json
    running_json=$(containerlab inspect --all --format json 2>/dev/null) || running_json="{}"

    # Find all topologies and categorize them
    for dir in "$CONTAINERLAB_DIR"/*/; do
        local name=$(basename "$dir")
        local topo_file="${dir}${name}.clab.yml"
        if [ -f "$topo_file" ]; then
            total_count=$((total_count + 1))
            if echo "$running_json" | jq -e --arg name "$name" 'has($name)' >/dev/null 2>&1; then
                running_topos+=("$name")
                running_count=$((running_count + 1))
            else
                stopped_topos+=("$name")
            fi
        fi
    done

    echo "📋 Topologies ($running_count running / $total_count total):"
    echo ""

    # Display running topologies first
    if [ ${#running_topos[@]} -gt 0 ]; then
        echo "   Running:"
        for topo in $(printf '%s\n' "${running_topos[@]}" | sort); do
            if [ "$topo" = "$current" ]; then
                echo "   ▶ $topo (current)"
            else
                echo "   • $topo"
            fi
        done
        echo ""
    fi

    # Display stopped topologies
    if [ ${#stopped_topos[@]} -gt 0 ]; then
        echo "   Stopped:"
        for topo in $(printf '%s\n' "${stopped_topos[@]}" | sort); do
            echo "   ○ $topo"
        done
    fi
}

# Command: current
cmd_current() {
    local current=$(get_current_topology)

    if [ -n "$current" ]; then
        local topo_path=$(get_topology_path "$current")
        echo "📍 Current topology: $current"
        echo "   Path: $topo_path"

        # Check if service is running
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            echo "   Status: Running"
        else
            echo "   Status: Stopped"
        fi
    else
        echo "ℹ️  No topology currently configured"
    fi
}

# Command: status
cmd_status() {
    echo "📊 TopoViewer Service Status:"
    echo ""

    # Service status
    local status=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "unknown")
    case "$status" in
        active)
            echo "   Service: ✅ Running"
            ;;
        inactive)
            echo "   Service: ⏹️  Stopped"
            ;;
        failed)
            echo "   Service: ❌ Failed"
            ;;
        *)
            echo "   Service: ❓ $status"
            ;;
    esac

    # Current topology
    local current=$(get_current_topology)
    if [ -n "$current" ]; then
        echo "   Topology: $current"
    else
        echo "   Topology: Not configured"
    fi

    # Uptime
    if [ "$status" = "active" ]; then
        local uptime=$(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp --value 2>/dev/null)
        if [ -n "$uptime" ]; then
            echo "   Started: $uptime"
        fi
    fi
}

# Command: help
cmd_help() {
    echo "TopoViewer Topology Switching Tool"
    echo ""
    echo "Usage:"
    echo "   switch-topoviewer.sh switch <name>  - Switch to a topology"
    echo "   switch-topoviewer.sh list           - List available topologies"
    echo "   switch-topoviewer.sh current        - Show current topology"
    echo "   switch-topoviewer.sh status         - Show service status"
    echo "   switch-topoviewer.sh help           - Show this help"
    echo ""
    echo "Examples:"
    echo "   switch-topoviewer.sh switch ddos-test-lab"
    echo "   switch-topoviewer.sh list"
}

# Main
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        switch)
            cmd_switch "$@"
            ;;
        list)
            cmd_list
            ;;
        current)
            cmd_current
            ;;
        status)
            cmd_status
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            echo "❌ Unknown command: $command"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
