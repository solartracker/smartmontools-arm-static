# smartmontools-arm-static

A minimal example showing how to compile **smartmontools** as a **statically linked executable** for ARMv7 Linux devices. This repository demonstrates **how to build from source** in a simple way that produces binaries you can run on any ARMv7 device.  

It includes two scripts:  

- `smartmontools-arm-musl.sh` — recommended, modern musl-based method. Prebuilt binaries are available.  
- `smartmontools-arm-tomatoware.sh` — older Tomatoware-based method, included as a reference example.

---

## Setup

### Using musl (recommended)

Prebuilt binaries for `smartctl` and `smartd` are available on the [Releases](https://github.com/solartracker/smartmontools-arm-static/releases) page.  

To build locally:

```bash
git clone https://github.com/solartracker/smartmontools-arm-static
cd smartmontools-arm-static
./smartmontools-arm-musl.sh
```

### Using Tomatoware (example)

```bash
git clone https://github.com/solartracker/smartmontools-arm-static
cd smartmontools-arm-static
./smartmontools-arm-tomatoware.sh
```

---

## Notes (Tomatoware build only)

- Executables are located under `/mmc/sbin` (`smartctl` and `smartd`).  
- Example scripts and configuration files are included in `/mmc/share/smartmontools` and `/mmc/etc`.
