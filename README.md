# AzerothCore 3.3.5a for Android (Termux)

A tuned, native [AzerothCore](https://www.azerothcore.org/) World of Warcraft (3.3.5a - WotLK) server emulator running directly on Android devices via **Termux**.

---

## 🌟 Acknowledgements & Inspiration

* **Inspiration & Concept:** Special thanks and credit to [duall/singlePlayerWow-android](https://github.com/duall/singlePlayerWow-android) for providing the original inspiration, concept, and groundwork for running a full AzerothCore server natively on Android.
* **Playerbots Integration:** Special thanks to the [mod-playerbots](https://github.com/mod-playerbots/azerothcore-wotlk) team for maintaining the Playerbot-enabled AzerothCore fork and bot framework.
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
   * Added `tools/build.sh`: One-command automated build pipeline that verifies Git submodules, configures CMake for Android, compiles with safe concurrency, and installs the server.
   * Added `tools/configure.sh`: Standalone CMake configurator with Android compiler flags and automatic deployment of server control tools.
   * Added `tools/db_setup.sh`: Automated MariaDB directory, service, and database initialization (`acore_auth`, `acore_characters`, `acore_world`, and `acore_playerbots`).
   * Added `tools/ac_server_start.sh` & `tools/ac_server_stop.sh`: Automated tmux launcher with dynamic Wi-Fi IP detection, CPU affinity pinning, and graceful shutdown handling.
   * Added `tools/sync_upstream.sh`: One-command upstream synchronization and rebase tracking `mod-playerbots/azerothcore-wotlk:Playerbot`.

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

Clone this repository with its submodules and switch to the `android-termux` branch:

```bash
git clone --recurse-submodules -b android-termux https://github.com/MickeyPickey/azerothcore-wotlk-android.git ~/azerothcore-src
cd ~/azerothcore-src
```

> **Note:** If you already cloned without `--recurse-submodules`, the build script will automatically detect and fetch all submodules for you.

---

### Step 3: Build & Install the Server

All bundled gameplay modules (`mod-playerbots`, `mod-ah-bot-plus`, `AutoBalance`, `Solo-LFG`, `mod-transmog`, `mod-learnspells`, etc.) are included and locked to verified commits via Git submodules.

Run the automated build script to configure, compile, and install the server in a single command:

```bash
./tools/build.sh
```

> 💡 **What does `./tools/build.sh` do automatically?**
> 1. Verifies and initializes any missing Git submodules (`git submodule update --init --recursive`).
> 2. Configures CMake with Android Clang compiler flags and linker settings.
> 3. Deploys server control scripts (`ac_server_start.sh`, `ac_server_stop.sh`, `db_setup.sh`, `build.sh`) to `~/azeroth-server/tools/`.
> 4. Compiles using safe dynamic concurrency (leaving 2 CPU cores free, e.g. `-j6` on 8-core chips) to prevent Android out-of-memory (`signal 9 / Killed`) aborts.
> 5. Installs the server binaries and assets to `~/azeroth-server/`.

> 💡 **Options & Customization:**
> - **Custom CPU jobs:** `./tools/build.sh -j 4`
> - **Clean rebuild:** `./tools/build.sh --clean`
> - **Configure only (no compilation):** `./tools/configure.sh`
> - **Disable specific modules (optional):** Pass CMake flags after `--`, e.g. `./tools/build.sh -- -DDISABLED_AC_MODULES="mod1;mod2"`

---

### Step 4: Database Setup (MariaDB)

Run our automated database setup script:

```bash
# Run from the repository root:
./tools/db_setup.sh

# Or run directly from your server directory:
~/azeroth-server/tools/db_setup.sh
```

This single command handles everything automatically:
- Initializes the MariaDB data directory (if not already done).
- Starts the MariaDB service in the background.
- Safely creates the required databases (`acore_auth`, `acore_characters`, `acore_world`, and `acore_playerbots`) and configures the default `acore` user.

<details>
<summary><b>Click here to view manual SQL commands (Advanced)</b></summary>

If you prefer to configure MariaDB manually:

1. Initialize and start MariaDB:
   ```bash
   mariadb-install-db
   mariadbd-safe --datadir="$PREFIX/var/lib/mysql" --user="$(whoami)" &
   ```

2. Open the MariaDB console:
   ```bash
   mariadb -u root
   ```

3. Execute SQL configuration:
   ```sql
   CREATE DATABASE IF NOT EXISTS acore_auth DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE DATABASE IF NOT EXISTS acore_characters DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE DATABASE IF NOT EXISTS acore_world DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE DATABASE IF NOT EXISTS acore_playerbots DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

   CREATE USER IF NOT EXISTS 'acore'@'localhost' IDENTIFIED BY 'acore';
   CREATE USER IF NOT EXISTS 'acore'@'127.0.0.1' IDENTIFIED BY 'acore';
   CREATE USER IF NOT EXISTS 'acore'@'%' IDENTIFIED BY 'acore';

   GRANT ALL PRIVILEGES ON acore_auth.* TO 'acore'@'localhost';
   GRANT ALL PRIVILEGES ON acore_characters.* TO 'acore'@'localhost';
   GRANT ALL PRIVILEGES ON acore_world.* TO 'acore'@'localhost';
   GRANT ALL PRIVILEGES ON acore_playerbots.* TO 'acore'@'localhost';

   GRANT ALL PRIVILEGES ON acore_auth.* TO 'acore'@'127.0.0.1';
   GRANT ALL PRIVILEGES ON acore_characters.* TO 'acore'@'127.0.0.1';
   GRANT ALL PRIVILEGES ON acore_world.* TO 'acore'@'127.0.0.1';
   GRANT ALL PRIVILEGES ON acore_playerbots.* TO 'acore'@'127.0.0.1';

   GRANT ALL PRIVILEGES ON *.* TO 'acore'@'%';
   FLUSH PRIVILEGES;
   EXIT;
   ```
</details>

---

### Step 5: Client Data (DBC, Maps, VMaps, MMaps)

To run `worldserver`, you need the pre-extracted 3.3.5a game data (`dbc/`, `maps/`, `vmaps/`, `mmaps/`, `Cameras/`).

Instead of extracting data yourself from a WoW client, you can use the ready-to-use **[AC Data v20 enUS (Latest)](https://github.com/wowgaming/client-data/releases/tag/v20.0)** release from `wowgaming/client-data`:

#### Direct Download via Termux:
```bash
# Create data folder inside your server directory
mkdir -p ~/azeroth-server/data && cd ~/azeroth-server/data

# Download AC Data v20 package (~1.4 GB)
curl -L -O https://github.com/wowgaming/client-data/releases/download/v20.0/Data.zip

# Unpack all data folders and remove zip
unzip Data.zip && rm Data.zip
```

> **Manual Download Alternative:**  
> You can also download `Data.zip` in your browser from the **[wowgaming/client-data v20.0 Release](https://github.com/wowgaming/client-data/releases/tag/v20.0)** page, transfer it to your device, and unpack it into `~/azeroth-server/data/`.

---

### Step 6: Configure Server Files

We provide pre-tuned configuration files optimized specifically for Android (Termux temp paths, CPU core pinning, mobile view distances, and module settings):

```bash
# Copy pre-configured Android configs into your server directory:
cp -r ~/azerothcore-src/conf/dist/android/* ~/azeroth-server/etc/
```

> **What's pre-configured?**
> - `DataDir = "."` (looks in `~/azeroth-server/` or `~/azeroth-server/data/`)
> - `TempDir = "/data/data/com.termux/files/usr/tmp"` (fixes crashes on missing desktop `/tmp`)
> - `UseProcessors = 3` (CPU core affinity tuned for mobile chipsets)
> - `Log.Async.Enable = 1` (asynchronous logging enabled for reduced mobile I/O overhead)
> - `Warden.Enabled = 0` (Warden disabled to eliminate client/server mobile incompatibilities)
> - Playerbots logging level tuned to `Info` (`Logger.playerbots = 3`) to minimize log bloat
> - Dedicated `acore_playerbots` database connection configured
> - Auto-clean dead DB references enabled (`Updates.CleanDeadRefMaxCount = -1`)
> - Visibility distances balanced for mobile RAM and smooth frame rates
> - Pre-configured default settings for all bundled gameplay modules (`playerbots`, `AHBot`, `AutoBalance`, `Solo-LFG`, `transmog`, etc.)

---

### Step 7: Launching the Server

We provide automated management scripts synced directly to `~/azeroth-server/tools/`:

```bash
# Start MariaDB, auto-detect Wi-Fi IP, update realmlist, and start authserver + worldserver in tmux:
~/azeroth-server/tools/ac_server_start.sh
# (or from the source repository: ./tools/ac_server_start.sh)

# To safely stop all server processes and MariaDB:
~/azeroth-server/tools/ac_server_stop.sh
# (or from the source repository: ./tools/ac_server_stop.sh)
```

> 💡 **CPU Pinning Note:**
> By default, `ac_server_start.sh` pins the server and database processes to **cores 0–1** (`CPU_CORES="0-1"`). This intentional allocation leaves your device's remaining CPU cores completely free so you can run the WoW client on the same device (via Winlator or GameNative) smoothly without lag.
> If you are hosting the server for PC / external players and want to grant the server more CPU power, you can easily tweak it by passing `CPU_CORES` when launching (e.g. `CPU_CORES="0-3" ~/azeroth-server/tools/ac_server_start.sh`) or modifying `CPU_CORES` in `ac_server_start.sh` (line 23).

> 💡 **Tmux Session Management:**
> When launched from an interactive terminal, `ac_server_start.sh` automatically attaches to tmux. If you detach (using `Ctrl+b` then `d`) or run in the background, you can re-attach at any time with:
> ```bash
> tmux attach -t wow_server
> ```

On first startup, `worldserver` will automatically populate the database tables using AzerothCore's `DBUpdater`.

---

## 🎮 Connecting Your Client

### Option 1: On the Same Android Device (via Winlator or GameNative)
If you are running the WoW 3.3.5a client directly on the same phone using Windows emulation tools such as [Winlator](https://github.com/brunodev85/winlator) or [GameNative](https://github.com/utkarshdalal/GameNative):
1. Open your client's `Data/enUS/realmlist.wtf` (or matching locale folder).
2. Set realmlist to localhost:
   ```text
   set realmlist 127.0.0.1
   ```

### Option 2: From a PC or Another Device (over Local Wi-Fi)
If your server is running on your phone and you want to connect from your PC over Wi-Fi:
1. When you launch the server with `ac_server_start.sh` (from `~/azeroth-server/tools/` or `./tools/`), it automatically detects your Wi-Fi IP and updates the `realmlist` table for you!
2. On your PC's WoW client, simply edit `Data/enUS/realmlist.wtf` to match your phone's Wi-Fi IP:
   ```text
   set realmlist <YOUR_PHONE_WLAN_IP>
   ```

---

## 🔄 Keeping Updated with Upstream AzerothCore (Playerbot branch)

This repository tracks upstream [`mod-playerbots/azerothcore-wotlk`](https://github.com/mod-playerbots/azerothcore-wotlk) (branch `Playerbot`), which continuously integrates official AzerothCore master updates while maintaining core hooks and compatibility for `mod-playerbots`.

To pull new core updates while cleanly keeping your Android fixes on top:

```bash
./tools/sync_upstream.sh
```
This script:
1. Fetches upstream changes from `mod-playerbots/azerothcore-wotlk` (`Playerbot` branch).
2. Fast-forwards your local `Playerbot` mirror and pushes it to `origin/Playerbot`.
3. Rebases `android-termux` cleanly on top of `Playerbot`.
4. Prompts you interactively to push the rebased `android-termux` to `origin` (or automatically with `--push` / `-p`):
   ```bash
   ./tools/sync_upstream.sh --push
   ```


---

## ❓ Troubleshooting & Performance FAQ

* **Compiler gets killed (`Killed` / `signal 9`):**
  * Android killed Clang due to low memory. Lower your parallel jobs: use `./tools/build.sh -j 4` (or lower) instead of maximum cores.
* **Server disconnects when phone screen locks:**
  * Android is putting Termux into battery sleep. Run `termux-wake-lock` and disable battery optimization for Termux in Android Settings.
* **Thermal Throttling:**
  * Compiling hundreds of C++ files generates heat. Keep your device in a cool environment or place it near a small fan during the initial build.
* **MariaDB Socket Error (`Can't connect to local server`):**
  * Ensure MariaDB is running. Check running status with `pgrep -f mariadbd` or re-run `./tools/db_setup.sh`.

---

## 📜 License

AzerothCore is open source software released under the [GNU AGPL v3](LICENSE).
