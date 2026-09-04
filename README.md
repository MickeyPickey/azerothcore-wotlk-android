# AzerothCore 3.3.5a for Android (Termux)

A tuned, native [AzerothCore](https://www.azerothcore.org/) World of Warcraft (3.3.5a - WotLK) server emulator running directly on Android devices via **Termux**.

---

## 🌟 Acknowledgements & Inspiration

* **Inspiration & Concept:** Special thanks and credit to [duall/singlePlayerWow-android](https://github.com/duall/singlePlayerWow-android) for proving that running a full WoW WotLK server natively on Android is possible, and providing the initial inspiration and configuration reference for mobile Termux deployments.
* **Upstream Project:** Built on top of the incredible ongoing work by the [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) team and community.

---

## 🛠️ Android & MariaDB Compatibility Fixes

Standard AzerothCore is written for x86_64 desktop Linux with Oracle MySQL 8.0+. Running natively on Android ARM64 under Termux requires addressing several platform-specific constraints:

1. **MariaDB Client Library Compatibility (`libmariadb`):**
   * Termux provides MariaDB rather than Oracle MySQL. AzerothCore's upstream MySQL driver attempts to use MySQL 8.3+ functions (such as `mysql_stmt_bind_named_param`) and modern SSL modes that do not exist in `libmariadb`.
   * **Fix applied:** Added `#if !defined(MARIADB_VERSION_ID)` preprocessor guards in `MySQLConnection.cpp`, `DBUpdater.cpp`, and `DatabaseWorkerPool` to smoothly support MariaDB 10.5+ and its SSL/binding APIs.
2. **Android Bionic libc 64-bit Integer Mapping:**
   * Android's Bionic C library defines `int64_t` / `uint64_t` in a way that causes template ambiguities in `PreparedStatement::SetData` when passing standard integral types and durations.
   * **Fix applied:** Added `std::is_same_v` constexpr type dispatching in `PreparedStatement.h` and `PreparedStatement.cpp` to properly coerce 64-bit values on Android.
3. **Thread Priority Privileges:**
   * Unrooted Android kernels restrict or deny `setpriority()` niceness changes for user processes.
   * **Fix applied:** Adjusted `ProcessPriority.cpp` to prevent permission errors when initializing worker threads.
4. **gSOAP & Network Stack:**
   * Fixed empty response handling in `deps/gsoap/stdsoap2.cpp` for mobile POSIX network environments.
5. **Modular Build & Sync Tool:**
   * Added `tools/pull_modules.sh` and `conf/modules.list` to download and update optional gameplay mods using shallow clones (`--depth 1`), keeping disk usage low and build times fast.

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

> **Tip:** Run `termux-wake-lock` to keep Termux active in the background while compiling or running the server.

---

### Step 2: Clone the Repository

Clone this repository and switch to the `termux-device` branch:

```bash
git clone -b termux-device https://github.com/MickeyPickey/azerothcore-wotlk.git ~/azerothcore-src
cd ~/azerothcore-src
```

---

### Step 3: (Optional) Select and Pull Modules

This repository includes a module manager that supports 40+ popular AzerothCore mods (Playerbots, AutoBalance, Solo-LFG, Transmog, etc.):

1. Open `conf/modules.list` in a text editor (e.g. `nano conf/modules.list`).
2. Uncomment (remove `#`) from the modules you want to include:
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

Create a `build` directory and run CMake with Android-specific flags:

```bash
mkdir -p build && cd build

cmake .. \
  -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server/ \
  -DCMAKE_C_COMPILER=$PREFIX/bin/clang \
  -DCMAKE_CXX_COMPILER=$PREFIX/bin/clang++ \
  -DWITH_WARNINGS=1 \
  -DTOOLS=0 \
  -DSCRIPTS=static \
  -DCMAKE_CXX_FLAGS="-D__ANDROID__ -DANDROID -Wno-deprecated-literal-operator" \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-multiple-definition -lunwind"
```

#### Compile with Make:

```bash
# Recommended: use 4 cores to prevent Android Out-Of-Memory (OOM) killer
make -j4

# Once compilation finishes, install binaries to ~/azeroth-server/
make install
```

> ⚠️ **Do NOT use `make -j8`:** Running 8 parallel compiler processes on Android consumes 4–6 GB of RAM, causing Android's kernel to kill the build (`signal 9 / Killed`). Sticking to `-j4` ensures stability.

---

### Step 5: Database Setup (MariaDB)

1. Initialize MariaDB data directory (one-time setup):
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
   GRANT ALL PRIVILEges ON acore_characters.* TO 'acore'@'127.0.0.1';
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
Edit `worldserver.conf` to configure `DataDir = "$HOME/azeroth-server/data"` (or path to your maps).

---

### Step 8: Launching the Server

Using `tmux` is highly recommended so your server sessions stay alive even if Termux is minimized:

```bash
# 1. Start a tmux session
tmux new -s wow_server

# 2. In Window 1, start Auth Server:
cd ~/azeroth-server/bin
./authserver

# 3. Split or create a new window (Ctrl+b then c), and start World Server:
cd ~/azeroth-server/bin
./worldserver
```

On first startup, `worldserver` will automatically populate the database tables using AzerothCore's `DBUpdater`.

---

## 🎮 Connecting Your Client

### Option 1: On the Same Android Device (via Winlator)
If you are running the WoW 3.3.5a client on the same device using [Winlator](https://github.com/brunodev85/winlator):
1. Open your client's `Data/enUS/realmlist.wtf` (or matching locale folder).
2. Set realmlist to localhost:
   ```text
   set realmlist 127.0.0.1
   ```

### Option 2: From a PC or Another Device (over Local Wi-Fi)
If your server is on your phone and you want to connect from your PC over Wi-Fi:
1. Find your Android phone's local Wi-Fi IP in Termux:
   ```bash
   ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
   ```
   *(Example: `192.168.1.150`)*
2. Update the realmlist in MariaDB:
   ```bash
   mariadb -u acore -pacore -e "UPDATE acore_auth.realmlist SET address = '192.168.1.150' WHERE id = 1;"
   ```
3. On your PC's WoW client, edit `Data/enUS/realmlist.wtf`:
   ```text
   set realmlist 192.168.1.150
   ```

---

## 🔄 Keeping Updated with Upstream AzerothCore

To pull new core updates from official AzerothCore while keeping your Android fixes intact:

```bash
# 1. Add upstream if not already added
git remote add upstream https://github.com/azerothcore/azerothcore-wotlk.git

# 2. Fetch latest commits
git fetch upstream master

# 3. Rebase your custom branch
git checkout termux-device
git rebase upstream/master

# 4. Push rebased branch to your GitHub fork
git push --force-with-lease origin termux-device
```

---

## ❓ Troubleshooting & Performance FAQ

* **Compiler gets killed (`Killed` / `signal 9`):**
  * Android killed Clang due to low memory. Lower your parallel jobs: use `make -j3` or `make -j4` instead of `-j8`.
* **Server disconnects when phone screen locks:**
  * Android is putting Termux into battery sleep. Run `termux-wake-lock` and disable battery optimization for Termux in Android Settings.
* **Thermal Throttling:**
  * Compiling hundreds of C++ files generates heat. Keep your device in a cool environment or place it near a small fan during the initial build.
* **MariaDB Socket Error (`Can't connect to local server`):**
  * Ensure MariaDB is running (`mysqld_safe &`). Check running status with `pgrep mysqld`.

---

## 📜 License

AzerothCore is open source software released under the [GNU AGPL v3](LICENSE).
