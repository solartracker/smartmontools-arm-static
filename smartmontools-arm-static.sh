#!/bin/sh
################################################################################
# smartmontools-arm-static.sh
#
# Raspberry Pi build script for Smartmontools
#
# The smartmontools package contains two utility programs (smartctl and smartd)
# to control and monitor storage systems using the Self-Monitoring, Analysis and
# Reporting Technology System (SMART) built into most modern ATA/SATA, SCSI/SAS
# and NVMe disks. In many cases, these utilities will provide advanced warning
# of disk degradation and failure.
#
# This script downloads and compiles all packages needed for adding these
# capabilities to any ARMv7 Linux device. All you do is run the script and copy
# the resulting executable program to the target device.
#
# The resulting executable program is statically linked and entirely 
# self-contained, there are no external libraries needed on the target
# device.
#
# This script uses the Tomatoware environment.
#
# Tomatoware is a modern, cross-compilation and build environment for ARM-based
# devices.  It provides a complete, self-contained toolchain under the /mmc
# directory, including up-to-date compilers, libraries, and build utilities.
# With Tomatoware, you can compile the latest versions of open-source packages 
# for ARMv7 and other older ARM platforms that would otherwise be stuck using
# outdated toolchains.
#
# The build environment is entirely contained under /mmc:
#   - All binaries, libraries, and configuration files are installed in /mmc.
#   - Nothing is written to host directories like /usr, /bin, or /lib.
#   - The host system remains untouched, preventing potential conflicts
#     or accidental overwrites during compilation.
#
# My specific purposes for this script are to build Smartmontools from source
# code and run it on the RT-AC68U router, which uses ARMv7 Linux 2.6. It is a
# simple example for how to do this sort of thing.
#
# The resulting smartctl and smartd programs are:
#   - Statically linked, requiring no external libraries on the RT-AC68U router.
#   - Self-contained, including drivedb.h and example scripts, all under /mmc.
#   - Ready to be copied to the RT-AC68U router without any host system dependency.
#
# Using Tomatoware and /mmc as the build root makes it easy to maintain
# multiple toolchains or versions and isolate them from the host environment.
# It also ensures that software compiled for older ARM systems can leverage
# modern features, optimizations, and bug fixes from the latest upstream packages.
#
# Copyright (C) 2025 Richard Elwell
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
################################################################################
PATH_CMD="$(readlink -f -- "$0")"
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "$0")")"
PARENT_DIR="$(dirname -- "$(dirname -- "$(readlink -f -- "$0")")")"
set -e
set -x

################################################################################
# Checksum verification for downloaded file

check_sha256() {
    file="$1"
    expected="$2"

    if [ ! -f "$file" ]; then
        echo "ERROR: File not found: $file"
        return 1
    fi

    actual="$(sha256sum "$file" | awk '{print $1}')"

    if [ "$actual" != "$expected" ]; then
        echo "ERROR: SHA256 mismatch for $file"
        echo "Expected: $expected"
        echo "Actual:   $actual"
        return 1
    fi

    echo "SHA256 OK: $file"
    return 0
}

################################################################################
# Install the build environment, if it is not already installed

TOMATOWARE_URL="https://github.com/lancethepants/tomatoware/releases/download/v5.0/arm-soft-mmc.tgz"
TOMATOWARE_SHA256="ff490819a16f5ddb80ec095342ac005a444b6ebcd3ed982b8879134b2b036fcc"
TOMATOWARE_PKG="arm-soft-mmc-5.0.tgz"
TOMATOWARE_DIR="tomatoware-5.0"
TOMATOWARE_PATH="$PARENT_DIR/$TOMATOWARE_DIR"
TOMATOWARE_SYSROOT="/mmc" # or, whatever your tomatoware distribution uses for sysroot

# Check if Tomatoware exists and install it, if needed
if [ ! -d "$TOMATOWARE_PATH" ]; then
    echo "Tomatoware not found at $TOMATOWARE_PATH. Installing..."
    echo ""
    cd $PARENT_DIR
    if [ ! -f "$TOMATOWARE_PKG" ]; then
        PKG_TMP=$(mktemp "$TOMATOWARE_PKG.XXXXXX")
        trap '[ -n "$PKG_TMP" ] && rm -f "$PKG_TMP"' EXIT INT TERM
        wget -O "$PKG_TMP" "$TOMATOWARE_URL"
        mv -fv "$PKG_TMP" "$TOMATOWARE_PKG"
        trap - EXIT INT TERM
    fi

    check_sha256 "$TOMATOWARE_PKG" "$TOMATOWARE_SHA256"

    DIR_TMP=$(mktemp -d "$TOMATOWARE_DIR.XXXXXX")
    trap '[ -n "$DIR_TMP" ] && rm -rf "$DIR_TMP"' EXIT INT TERM
    mkdir -pv "$DIR_TMP"
    tar xzvf "$TOMATOWARE_PKG" -C "$DIR_TMP"
    mv -fv "$DIR_TMP" "$TOMATOWARE_DIR"
    trap - EXIT INT TERM
fi

# Check if /mmc exists and is a symbolic link
if [ ! -L "$TOMATOWARE_SYSROOT" ] && ! grep -q " $TOMATOWARE_SYSROOT " /proc/mounts; then
    echo "Tomatoware $TOMATOWARE_SYSROOT is missing or is not a symbolic link."
    echo ""
    # try making a symlink
    if ! sudo ln -sfnv "$TOMATOWARE_PATH" "$TOMATOWARE_SYSROOT"; then
        # otherwise, we are probably on a read-only filesystem and
        # the sysroot needs to be already baked into the firmware and
        # not in use by something else.
        # alternatively, you can figure out another sysroot to use.
        mount -o bind "$TOMATOWARE_PATH" "$TOMATOWARE_SYSROOT"
    fi
fi

# Check for required Tomatoware tools
if [ ! -x "$TOMATOWARE_SYSROOT/bin/gcc" ] || [ ! -x "$TOMATOWARE_SYSROOT/bin/make" ]; then
    echo "ERROR: Tomatoware installation appears incomplete."
    echo "Missing gcc or make in $TOMATOWARE_SYSROOT/bin."
    echo ""
    exit 1
fi

# Check shell
if [ "$BASH" != "$TOMATOWARE_SYSROOT/bin/bash" ]; then
    if [ -z "$TOMATOWARE_SHELL" ]; then
        export TOMATOWARE_SHELL=1
        exec "$TOMATOWARE_SYSROOT/bin/bash" "$PATH_CMD" "$@"
    else
        echo "ERROR: Not Tomatoware shell: $(readlink /proc/$$/exe)"
        echo ""
        exit 1
    fi
fi

# ---- From here down, you are running under /mmc/bin/bash ----
echo "Now running under: $(readlink /proc/$$/exe)"

################################################################################
# General

PKG_ROOT=smartmontools
REBUILD_ALL=1
SRC="$TOMATOWARE_SYSROOT/src/$PKG_ROOT"
mkdir -pv "$SRC"
#MAKE="make -j$(grep -c ^processor /proc/cpuinfo)" # make runs with parallelism
MAKE="make -j1"                                    # make runs one job at a time
PATH="$TOMATOWARE_SYSROOT/usr/bin:$TOMATOWARE_SYSROOT/usr/local/sbin:$TOMATOWARE_SYSROOT/usr/local/bin:$TOMATOWARE_SYSROOT/usr/sbin:$TOMATOWARE_SYSROOT/sbin:$TOMATOWARE_SYSROOT/bin"

################################################################################
# smartmontools-7.5

PKG_MAIN=smartmontools
mkdir -pv "$SRC/$PKG_MAIN" && cd "$SRC/$PKG_MAIN"
DL="smartmontools-7.5.tar.gz"
DL_SHA256="690b83ca331378da9ea0d9d61008c4b22dde391387b9bbad7f29387f2595f76e"
FOLDER="${DL%.tar.gz*}"
URL="https://github.com/smartmontools/smartmontools/releases/download/RELEASE_7_5/$DL"

if [ "$REBUILD_ALL" == "1" ]; then
    if [ -f "$FOLDER/Makefile" ]; then
        cd "$FOLDER" && make uninstall && cd ..
    fi || true
    rm -rfv "$FOLDER"
fi || true

if [ ! -f "$FOLDER/__package_installed" ]; then
    [ ! -f "$DL" ] && wget "$URL"

    check_sha256 "$DL" "$DL_SHA256"

    [ ! -d "$FOLDER" ] && tar xzvf "$DL"
    cd "$FOLDER"

    PKG_CONFIG_PATH="$TOMATOWARE_SYSROOT/lib/pkgconfig" \
        ./configure LDFLAGS="-static" --prefix="$TOMATOWARE_SYSROOT"

    $MAKE
    make install

    # Stripping removes debug symbols and other metadata, shrinking the size by roughly 80%.
    # The executable programs will still be quite large because of static linking.
    [ -f "$TOMATOWARE_SYSROOT/sbin/smartctl" ] && strip "$TOMATOWARE_SYSROOT/sbin/smartctl"
    [ -f "$TOMATOWARE_SYSROOT/sbin/smartd" ] && strip "$TOMATOWARE_SYSROOT/sbin/smartd"

    touch __package_installed
fi

