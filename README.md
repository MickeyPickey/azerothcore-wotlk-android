# AzerothCore 3.3.5a for Android (Termux)

A tuned, native [AzerothCore](https://www.azerothcore.org/) World of Warcraft (3.3.5a - WotLK) server emulator running directly on Android devices via **Termux**.

---

## 🌟 Acknowledgements & Inspiration

* **Inspiration & Concept:** Special thanks and credit to [duall/singlePlayerWow-android](https://github.com/duall/singlePlayerWow-android) for providing the original inspiration, concept, and groundwork for running a full AzerothCore server natively on Android.
* **Upstream Project:** Built on top of the incredible work by the [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) team and community.

---

## 🛠️ Android & MariaDB Compatibility Fixes

Standard AzerothCore is written for desktop Linux with Oracle MySQL 8.0+. Running natively on Android ARM64 under Termux requires addressing several platform-specific constraints:

1. **MariaDB Client Library Compatibility (`libmariadb`):**
   * Termux provides MariaDB rather than Oracle MySQL. AzerothCore upstream attempts to use MySQL 8.3+ functions (such as `mysql_stmt_bind_named_param`) and modern SSL modes that do not exist in `libmariadb`.
   * **Fix applied:** Added `#if !defined(MARIADB_VERSION_ID)` preprocessor guards in `MySQLConnection.cpp`, `DBUpdater.cpp`, and `DatabaseWorkerPool` to smoothly support MariaDB 10.5+ and its SSL/binding APIs.
2. **Android Bionic libc 64-bit Integer Mapping:**
   * Android's Bionic C library defines `int64_t` / `uint64_t` in a way that causes template ambiguities in `PreparedStatement::SetData` when passing standard integral types and durations.
   * **Fix applied:** Added `std::is_same_v` constexpr type dispatching in `PreparedStatement.h` and `PreparedStatement.cpp` to properly coerce 64-bit values on Android.
3. **Thread Priority Privileges:**
   * Unrooted Android kernels restrict or deny `setpriority()` niceness changes for user processes.
   * **Fix applied:** Adjusted `ProcessPriority.cpp` to prevent permission errors when initializing worker threads.
4. **gSOAP & Network Stack:**
   * Fixed empty response handling in `deps/gsoap/stdsoap2.cpp` for mobile POSIX network environments.
5. **Built-in Automation Suite:**
   * Added `tools/pull_modules.sh`: Module manager supporting 40+ optional mods using shallow clones (`--depth 1`).
   * Added `tools/configure.sh`: One-command CMake configuration with Android compiler flags.
   * Added `tools/ac_server_start.sh` & `tools/ac_server_stop.sh`: Automated tmux launcher with dynamic Wi-Fi IP detection.
   * Added `tools/sync_upstream.sh`: One-command upstream synchronization and rebase.

---

## 📋 System Requirements

* **OS:** Android 10+ (64-bit ARM / `aarch64`)
* **RAM:** 6 GB minimum (8 GB+ recommended for running worldserver + client simultaneously)
* **Storage:** 25 GB+ free internal storage (for server build, MariaDB, and game data: DBC/Maps/VMaps/MMaps)
* **Terminal App:** [Termux (F-Droid release)](https://f-droid.org/en/packages/com.termux/) — *Do NOT install Termux from Google Play Store as it is deprecated and broken.*

---

## 🚀 Installation Guide

### Step 1: Install Dependencies in Termux

Open Termux and install the required build tools and libraries:

```bash
pkg update && pkg upgrade -y
pkg install git cmake make clang mariadb boost-headers boost-static tmux libc++ curl unzip -y
```

> **Tip:** Run `termux-wake-lock` to prevent Android from putting Termux to sleep during compilation.

---

### Step 2: Clone the Repository

Clone this repository and switch to the `android-termux` branch:

```bash
git clone -b android-termux https://github.com/MickeyPickey/azerothcore-wotlk-android.git ~/azerothcore-src
cd ~/azerothcore-src
```

---

### Step 3: (Optional) Select and Pull Modules

This repository includes a pre-configured module list supporting 40+ popular AzerothCore mods (Playerbots, AutoBalance, Solo-LFG, Transmog, etc.):

1. Open `conf/modules.list` in a text editor (e.g. `nano conf/modules.list`).
2. Uncomment (remove `#`) from the modules you want to enable:
   ```text
   # Example: enable AutoBalance and Solo-LFG
   https://github.com/azerothcore/mod-autobalance.git
   https://github.com/azerothcore/mod-solo-lfg.git
   ```
3. Run the pull script to fetch them with fast, storage-saving shallow clones (`--depth 1`):
   ```bash
   ./tools/pull_modules.sh
   ```

---

### Step 4: Configure and Compile

We provide a helper script that automatically applies all Android Clang and linker flags:

```bash
# 1. Run the Android CMake configurator
./tools/configure.sh

# 2. Compile using (max cores - 2) parallel jobs to prevent Android OOM crashes:
cd build
make -j$(($(nproc) - 2))

# 3. Install binaries to ~/azeroth-server/
make install
```

> ⚠️ **CPU Core Recommendation:** Always leave at least 2 CPU cores free (e.g. `make -j$(($(nproc) - 2))`). Compiling on all available cores consumes too much RAM and causes Android's kernel to kill the build (`signal 9 / Killed`). For instance, on an 8-core device, use `-j6` (or `-j4` if you have limited RAM).

---

### Step 5: Database Setup (MariaDB)

1. Initialize the MariaDB data directory (one-time setup):
   ```bash
   mariadb-install-db
   ```

2. Start the MariaDB service in the background:
   ```bash
   mysqld_safe --datadir="$PREFIX/var/lib/mysql" &
   ```

3. Configure the database and default AzerothCore user:
   ```bash
   mariadb -u root
   ```
   Inside the MariaDB shell, run:
   ```sql
   CREATE DATABASE acore_auth;
   CREATE DATABASE acore_characters;
   CREATE DATABASE acore_world;

   CREATE USER 'acore'@'localhost' IDENTIFIED BY 'acore';
   CREATE USER 'acore'@'127.0.0.1' IDENTIFIED BY 'acore';
   CREATE USER 'acore'@'%' IDENTIFIED BY 'acore';

   GRANT ALL PRIVILEGES ON acore_auth.* TO 'acore'@'localhost';
   GRANT ALL PRIVILEGES ON acore_characters.* TO 'acore'@'localhost';
   GRANT ALL PRIVILEGES ON acore_world.* TO 'acore'@'localhost';

   GRANT ALL PRIVILEGES ON acore_auth.* TO 'acore'@'127.0.0.1';
   GRANT ALL PRIVILEGES ON acore_characters.* TO 'acore'@'127.0.0.1';
   GRANT ALL PRIVILEGES ON acore_world.* TO 'acore'@'127.0.0.1';

   GRANT ALL PRIVILEGES ON *.* TO 'acore'@'%';
   FLUSH PRIVILEGES;
   EXIT;
   ```

---

### Step 6: Client Data (DBC, Maps, VMaps, MMaps)

To run `worldserver`, you need the extracted 3.3.5a game data:
- `dbc/`
- `maps/`
- `vmaps/`
- `mmaps/`
- `Cameras/`

Place these folders directly inside your server directory:
```bash
~/azeroth-server/data/
# or directly under ~/azeroth-server/ (ensure DataDir in worldserver.conf points to their location)
```

---

### Step 7: Configure Server Files

Navigate to the installed server configuration directory:
```bash
cd ~/azeroth-server/etc
cp authserver.conf.dist authserver.conf
cp worldserver.conf.dist worldserver.conf
```
Edit `worldserver.conf` and set `DataDir = "$HOME/azeroth-server/data"` (or the path where your maps are located).

---

### Step 8: Launching the Server

We provide automated management scripts in `tools/`:

```bash
# Start MariaDB, auto-detect Wi-Fi IP, update realmlist, and start authserver + worldserver in tmux:
./tools/ac_server_start.sh

# To safely stop all server processes and MariaDB:
./tools/ac_server_stop.sh
```

On first startup, `worldserver` will automatically populate the database tables using AzerothCore's `DBUpdater`.

---

## 🎮 Connecting Your Client

### Option 1: On the Same Android Device (via Winlator)
If you are running the WoW 3.3.5a client on the same phone using [Winlator](https://github.com/brunodev85/winlator):
1. Open your client's `Data/enUS/realmlist.wtf` (or matching locale folder).
2. Set realmlist to localhost:
   ```text
   set realmlist 127.0.0.1
   ```

### Option 2: From a PC or Another Device (over Local Wi-Fi)
If your server is running on your phone and you want to connect from your PC over Wi-Fi:
1. When you launch the server with `./tools/ac_server_start.sh`, it automatically detects your Wi-Fi IP and updates the `realmlist` table for you!
2. On your PC's WoW client, simply edit `Data/enUS/realmlist.wtf` to match your phone's Wi-Fi IP:
   ```text
   set realmlist <YOUR_PHONE_WLAN_IP>
   ```

---

## 🔄 Keeping Updated with Upstream AzerothCore

To pull new core updates from official AzerothCore while cleanly keeping your Android fixes on top:

```bash
./tools/sync_upstream.sh
```
This script fetches official commits, checks for updates, rebases `android-termux` cleanly on top of `upstream/master`, and guides you to push to your fork.

---

## ❓ Troubleshooting & Performance FAQ

* **Compiler gets killed (`Killed` / `signal 9`):**
  * Android killed Clang due to low memory. Lower your parallel jobs: use `make -j$(($(nproc) - 2))` or lower instead of maximum cores.
* **Server disconnects when phone screen locks:**
  * Android is putting Termux into battery sleep. Run `termux-wake-lock` and disable battery optimization for Termux in Android Settings.
* **Thermal Throttling:**
  * Compiling hundreds of C++ files generates heat. Keep your device in a cool environment or place it near a small fan during the initial build.
* **MariaDB Socket Error (`Can't connect to local server`):**
  * Ensure MariaDB is running (`mysqld_safe &`). Check running status with `pgrep mysqld`.

---

## 📜 License

AzerothCore is open source software released under the [GNU AGPL v3](LICENSE).
