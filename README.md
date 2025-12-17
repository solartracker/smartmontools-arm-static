# Build Instructions

This repository contains a build script (`smartmontools-arm-static.sh`) for compiling **smartmontools** as statically linked executables for ARMv7 devices using **Tomatoware**.

---

## What is Tomatoware?

Tomatoware is a modern, self-contained ARM cross-compilation toolchain. It allows you to compile the latest open-source packages for older ARM systems that were previously stuck on out-of-date toolchains. It provides up-to-date compilers, libraries, and utilities in a single environment, fully isolated from your host system. Using Tomatoware ensures that builds are reproducible and safe, without modifying or interfering with host libraries or binaries.

---

## Setup Instructions

1. **Download Tomatoware binaries**

   ```bash
   cd
   wget https://github.com/lancethepants/tomatoware/releases/download/v5.0/arm-soft-mmc.tgz
   ```

2. **Unpack Tomatoware**

   ```bash
   mkdir -p tomatoware-5.0
   tar -xzf arm-soft-mmc.tgz -C tomatoware-5.0
   ```

   This creates `$HOME/tomatoware-5.0`.

3. **Create a symbolic link for Tomatoware environment**

   ```bash
   sudo ln -sfn $HOME/tomatoware-5.0 /mmc
   ```

   All scripts and build commands will use `/mmc` as the root of the Tomatoware environment.

4. **Clone this repository**

   ```bash
   cd
   git clone https://github.com/solartracker/smartmontools-arm-static
   cd smartmontools-arm-static
   ```

5. **Run the build script**

   ```bash
   ./smartmontools-arm-static.sh
   ```

   This will build `smartctl` and `smartd` as **statically linked binaries** under `/mmc/sbin`. You can copy these binaries directly to your ARM target.

---

## Notes

- The `/mmc` environment is isolated. Nothing is installed on the host system, preventing conflicts with existing libraries or programs.  
- The resulting binaries are **fully self-contained** and do not rely on the target system's libraries.  
- Optional: You can update or customize Tomatoware to add packages or new compiler versions, but it is not necessary for building smartmontools.  
- Example scripts and configuration files are included in `/mmc/share/smartmontools` and `/mmc/etc`.

---

## License

This project is licensed under the GNU General Public License (GPL) v3 or later. See [LICENSE](./LICENSE) for details.

