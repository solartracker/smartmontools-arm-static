# smartmontools-arm-static

This repository contains a build script (`smartmontools-arm-static.sh`) for compiling **smartmontools** as a statically linked executable for ARMv7 Linux devices.

---

## What is Smartmontools?

Smartmontools is a set of utility programs to control and monitor computer storage systems using the Self-Monitoring, Analysis and Reporting Technology system built into most modern ATA, Serial ATA, SCSI/SAS and NVMe hard drives.

## What is Tomatoware?

Tomatoware is a modern, self-contained ARM cross-compilation toolchain. It allows you to compile the latest open-source packages for older ARM systems that were previously stuck on out-of-date toolchains. It provides up-to-date compilers, libraries, and utilities in a single environment, fully isolated from your host system. Using Tomatoware ensures that builds are reproducible and safe, without modifying or interfering with host libraries or binaries.

---

## Setup Instructions

1. **Clone this repository**

   ```bash
   git clone https://github.com/solartracker/smartmontools-arm-static
   cd smartmontools-arm-static
   ```

2. **Run the build script**

   ```bash
   ./smartmontools-arm-static.sh
   ```

   This will build `smartctl` and `smartd` as **statically linked binaries** under `/mmc/sbin`. You can copy these binaries directly to your ARM target device.

---

## Notes

- The executable program is located here: `/mmc/sbin/smartctl`.  Copy it to your target device.
- The `/mmc` environment is isolated. Nothing is installed on the host system, preventing conflicts with existing libraries or programs.  
- Resulting binaries are **fully self-contained** and do not rely on the target system's libraries.  
- Optional: You can update or customize Tomatoware to add packages or new compiler versions, but it is not necessary for building smartmontools.  
- Example scripts and configuration files are included in `/mmc/share/smartmontools` and `/mmc/etc`.

