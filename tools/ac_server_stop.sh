#!/bin/bash
SESSION_NAME="wow_server"

echo "[+] Остановка игровых серверов..."
# Отправляем команду мягкого завершения в tmux-панель worldserver
tmux send-keys -t "$SESSION_NAME":0.1 "server shutdown 1" C-m
sleep 3

# Добиваем процессы, если они еще висят
pkill -f "worldserver" || true
pkill -f "authserver" || true

echo "[+] Корректная остановка MariaDB..."
mariadb-admin -u root shutdown

echo "[+] Закрытие сессии tmux..."
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux kill-session -t "$SESSION_NAME"
fi

echo "[✓] Все сервисы безопасно остановлены!"
