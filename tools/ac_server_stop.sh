#!/usr/bin/env bash
SESSION_NAME="${SESSION_NAME:-wow_server}"

echo "[+] Stopping game servers..."
# Send graceful shutdown command to worldserver tmux pane
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux send-keys -t "$SESSION_NAME":0.1 "server shutdown 1" C-m 2>/dev/null || true
fi

# Wait for worldserver graceful shutdown (up to 15 seconds)
for _ in {1..15}; do
    pgrep -f "worldserver" >/dev/null 2>&1 || break
    sleep 1
done

# Terminate remaining processes if still running
pkill -f "worldserver" 2>/dev/null || true
pkill -f "authserver" 2>/dev/null || true

echo "[+] Gracefully shutting down MariaDB..."
pkill -f "mariadbd-safe" 2>/dev/null || true
mariadb-admin -u root shutdown 2>/dev/null || pkill -f "mariadbd" 2>/dev/null || true

for _ in {1..10}; do
    pgrep -f "mariadbd" >/dev/null 2>&1 || break
    sleep 1
done

echo "[+] Closing tmux session..."
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux kill-session -t "$SESSION_NAME"
fi

echo "[✓] All services safely stopped!"
