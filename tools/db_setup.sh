#!/usr/bin/env bash
# ==============================================================================
# Automated MariaDB Database & User Setup for AzerothCore on Android (Termux)
# ==============================================================================
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
MYSQL_DATADIR="${PREFIX}/var/lib/mysql"
DB_USER="${DB_USER:-acore}"
DB_PASS="${DB_PASS:-acore}"

echo "======================================================================"
echo "Initializing MariaDB & AzerothCore Databases"
echo "Data directory: ${MYSQL_DATADIR}"
echo "Database user:  ${DB_USER}"
echo "======================================================================"

# Step 1: Initialize data directory if needed
if [ ! -d "${MYSQL_DATADIR}/mysql" ]; then
  echo "[+] Initializing MariaDB data directory with mariadb-install-db..."
  mariadb-install-db
  echo "[✓] MariaDB data directory initialized."
else
  echo "[✓] MariaDB data directory already exists."
fi

# Step 2: Ensure MariaDB service is running
if ! mariadb -u root -e "SELECT 1;" >/dev/null 2>&1; then
  echo "[+] Starting MariaDB daemon in background..."
  mariadbd-safe --datadir="${MYSQL_DATADIR}" --user="$(whoami)" >/dev/null 2>&1 &

  echo "[-] Waiting for MariaDB service to accept connections..."
  DB_READY=false
  for _ in {1..20}; do
    if mariadb -u root -e "SELECT 1;" >/dev/null 2>&1; then
      DB_READY=true
      break
    fi
    sleep 1
  done

  if [ "${DB_READY}" != true ]; then
    echo "[ERROR] MariaDB failed to start within 20 seconds." >&2
    echo "Check if another instance is running with: pgrep mysqld" >&2
    exit 1
  fi
fi
echo "[✓] MariaDB service is active and responsive."

# Step 3: Create databases and user safely (non-destructive)
echo "[+] Configuring databases and permissions..."

mariadb -u root <<EOSQL
CREATE DATABASE IF NOT EXISTS acore_auth DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS acore_characters DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS acore_world DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';

ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON acore_auth.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON acore_characters.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON acore_world.* TO '${DB_USER}'@'localhost';

GRANT ALL PRIVILEGES ON acore_auth.* TO '${DB_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON acore_characters.* TO '${DB_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON acore_world.* TO '${DB_USER}'@'127.0.0.1';

GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

echo "[✓] Databases 'acore_auth', 'acore_characters', and 'acore_world' are ready."
echo "[✓] User '${DB_USER}' configured with full permissions."
echo ""
echo "======================================================================"
echo "Database setup completed successfully!"
echo "======================================================================"
