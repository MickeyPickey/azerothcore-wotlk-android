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
   * Added `tools/db_setup.sh`: Automated MariaDB directory, service, and database/user initialization.
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

### Step 3: Select and Pull Modules

This repository includes a pre-configured module list supporting 40+ popular AzerothCore mods with a **stable lockfile** to prevent broken builds:

1. Open `conf/modules.list` in a text editor (e.g. `nano conf/modules.list`).
2. We have enabled 24 curated modules out-of-the-box (`mod-playerbots`, `AutoBalance`, `Solo-LFG`, `Transmog`, etc.). Uncomment or comment (`#`) any mods you want to add or remove.
3. Run the pull script:
   ```bash
   # Default: Clones and pins all enabled modules to verified, STABLE commits:
   ./tools/pull_modules.sh

   # (Optional) Want bleeding-edge latest upstream versions?
   ./tools/pull_modules.sh --latest

   # If an upstream update ever fails or breaks compilation, instantly roll back:
   ./tools/pull_modules.sh --stable
   # (Or roll back a specific module: ./tools/pull_modules.sh --stable mod-playerbots)
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

Run our automated database setup script:

```bash
./tools/db_setup.sh
```

This single command handles everything automatically:
- Initializes the MariaDB data directory (if not already done).
- Starts the MariaDB service in the background.
- Safely creates the required databases (`acore_auth`, `acore_characters`, `acore_world`) and configures the default `acore` user.

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
   CREATE DATABASE acore_auth DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE DATABASE acore_characters DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE DATABASE acore_world DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

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
</details>

---

### Step 6: Client Data (DBC, Maps, VMaps, MMaps)

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

### Step 7: Configure Server Files

We provide pre-tuned configuration files optimized specifically for Android (Termux temp paths, CPU core pinning, mobile view distances, and module settings):

```bash
# Copy pre-configured Android configs into your server directory:
cp -r conf/dist/android/* ~/azeroth-server/etc/
```

> **What's pre-configured?**
> - `DataDir = "."` (looks in `~/azeroth-server/` or `~/azeroth-server/data/`)
> - `TempDir = "/data/data/com.termux/files/usr/tmp"` (fixes crashes on missing desktop `/tmp`)
> - `UseProcessors = 3` (CPU core affinity tuned for mobile chipsets)
> - Visibility distances balanced for mobile RAM and smooth frame rates
> - Pre-configured default settings for all bundled gameplay modules (`playerbots`, `AutoBalance`, `Solo-LFG`, `transmog`, etc.)

---

### Step 8: Launching the Server

We provide automated management scripts in `tools/`:

```bash
# Start MariaDB, auto-detect Wi-Fi IP, update realmlist, and start authserver + worldserver in tmux:
./tools/ac_server_start.sh

# To safely stop all server processes and MariaDB:
./tools/ac_server_stop.sh
```

> 💡 **CPU Pinning Note:**  
> By default, `ac_server_start.sh` pins the server and database processes to **cores 0–1** (`CPU_CORES="0-1"`). This intentional allocation leaves your device's remaining CPU cores completely free so you can run the WoW client on the same device (via Winlator) smoothly without lag.  
> If you are hosting the server for PC / external players and want to grant the server more CPU power, you can easily tweak it by passing `CPU_CORES` when launching (e.g. `CPU_CORES="0-3" ./tools/ac_server_start.sh`) or editing line 14 of `tools/ac_server_start.sh`.

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
