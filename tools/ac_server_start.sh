#!/usr/bin/env bash

# ==============================================================================
# Script: ac_server_start.sh
# Purpose: Start MariaDB, configure realmlist IP, and launch AzerothCore in tmux
# Usage: ./ac_server_start.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# Configuration & Paths
# ------------------------------------------------------------------------------
SERVER_DIR="${SERVER_DIR:-$HOME/azeroth-server}"
SESSION_NAME="${SESSION_NAME:-wow_server}"
CPU_CORES="${CPU_CORES:-0-1}"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
MYSQL_DATADIR="$PREFIX/var/lib/mysql"

DB_USER="${DB_USER:-acore}"
DB_PASS="${DB_PASS:-acore}"
DB_AUTH_NAME="${DB_AUTH_NAME:-acore_auth}"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

# Resolve Wi-Fi IPv4 address or fallback to localhost
resolve_wlan_ip() {
    local ip=""
    # 1. Try iproute2 (ip addr show)
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 addr show 2>/dev/null | awk '/inet / && /wlan/ {print $2}' | cut -d/ -f1 | head -n1)
    fi
    # 2. Try Android system ip binary fallback
    if [ -z "$ip" ] && [ -x /system/bin/ip ]; then
        ip=$(/system/bin/ip -4 addr show 2>/dev/null | awk '/inet / && /wlan/ {print $2}' | cut -d/ -f1 | head -n1)
    fi
    # 3. Fallback to ifconfig parsing
    if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null | awk '/^wlan/ {w=1; next} /^[a-zA-Z]/ {w=0} w && /inet / {print $2; exit}')
    fi

    if [ -n "$ip" ] && [ "$ip" != "Not Connected" ]; then
        echo "$ip"
    else
        echo "127.0.0.1"
    fi
}

# ------------------------------------------------------------------------------
# Main Execution Pipeline
# ------------------------------------------------------------------------------

echo "=========================================================="
echo "🚀 Starting AzerothCore Server Environment"
echo "📅 Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================================="

# 1. Clean up lingering server processes to prevent "Address already in use"
echo "[+] Step 1/5: Cleaning up previous server binaries..."
pkill -f "worldserver" || true
pkill -f "authserver" || true

# 2. Restart MariaDB cleanly
echo "[+] Step 2/5: Restarting MariaDB service..."
pkill -f "mariadbd" 2>/dev/null || true
sleep 2

echo "[-] Launching fresh MariaDB instance (cores $CPU_CORES)..."
taskset -c "$CPU_CORES" mariadbd-safe --datadir="$MYSQL_DATADIR" --user="$(whoami)" > /dev/null 2>&1 &

echo "[-] Waiting for database initialization..."
DB_READY=false
for _ in {1..30}; do
    if mariadb -u root -e "SELECT 1;" >/dev/null 2>&1; then
        DB_READY=true
        break
    fi
    sleep 1
done

if [ "$DB_READY" != true ]; then
    echo "❌ Error: MariaDB failed to initialize within 30 seconds."
    exit 1
fi
echo "[✓] MariaDB is ready and accepting connections."

# 3. Resolve Wi-Fi IP and update realmlist address
echo "[+] Step 3/5: Detecting network IP configuration..."
REALMLIST_IP=$(resolve_wlan_ip)

if [ "$REALMLIST_IP" != "127.0.0.1" ]; then
    echo "[+] Detected WLAN IP: $REALMLIST_IP"
else
    echo "[-] Wi-Fi is not connected. Defaulting to local loopback (127.0.0.1)."
fi

echo "[+] Updating realm address in database: $REALMLIST_IP..."
mariadb -u "$DB_USER" -p"$DB_PASS" -e "UPDATE ${DB_AUTH_NAME}.realmlist SET address = '$REALMLIST_IP';"
echo "[✓] Realmlist address updated successfully."

# 4. Clean up any existing tmux session
echo "[+] Step 4/5: Managing tmux workspace..."
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "[-] Terminating existing tmux session: $SESSION_NAME..."
    tmux kill-session -t "$SESSION_NAME"
fi

# 5. Build tmux session layout and launch server binaries
echo "[+] Step 5/5: Initializing tmux panels with CPU pinning (cores $CPU_CORES)..."

# Create root session with working directory set to server directory
tmux new-session -d -s "$SESSION_NAME" -c "$SERVER_DIR"
sleep 0.5

# Panel 0.0: authserver pinned to designated CPU cores
tmux send-keys -t "$SESSION_NAME":0.0 "taskset -c $CPU_CORES $SERVER_DIR/bin/authserver" C-m

# Panel 0.1: worldserver pinned to designated CPU cores
tmux split-window -v -c "$SERVER_DIR"
sleep 0.5
tmux send-keys -t "$SESSION_NAME":0.1 "taskset -c $CPU_CORES $SERVER_DIR/bin/worldserver" C-m
sleep 0.5

# Panel 0.2: Interactive Bash workspace for administration
tmux split-window -v -c "$HOME"

# Equalize vertical layout
tmux select-layout -t "$SESSION_NAME" even-vertical

echo "=========================================================="
echo "✅ Server started! Attaching to tmux session: $SESSION_NAME"
echo "=========================================================="

# Attach to tmux session
exec tmux attach-session -t "$SESSION_NAME"
