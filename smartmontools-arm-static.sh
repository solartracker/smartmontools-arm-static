#!/mmc/bin/bash
################################################################################
# Raspberry Pi build script for:
# smartmontools
#
# This script downloads and compiles all packages needed for adding
# HDD SMART querying capabilities to any ARMv7 Linux device. All you do is
# run the script and copy the resulting executable program to the target
# device.
#
# The resulting executable program is statically linked and entirely 
# self-contained, there are no external libraries needed on the target
# device.
#
# This script uses the Tomatoware environment.
# It is a simple example for how to do this sort of thing.
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
# My specific purposes with this script is to build smartmontools from source
# code and run it on the RT-AC68U home router, which uses ARMv7 Linux 2.6.
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
PATH_CMD="$(readlink -f $0)"
set -e
set -x

TOMATOWARE_URL=https://github.com/lancethepants/tomatoware/releases/download/v5.0/arm-soft-mmc.tgz
TOMATOWARE_PKG=arm-soft-mmc-5.0.tgz
TOMATOWARE_DIR=tomatoware-5.0
TOMATOWARE_PATH=$HOME/$TOMATOWARE_DIR
TOMATOWARE_SYSROOT=/mmc # do not change this, unless you've customized and rebuilt Tomatoware from source code

# Check if Tomatoware directory exists
if [ ! -d "$TOMATOWARE_PATH" ]; then
    echo "Tomatoware not found at $TOMATOWARE_PATH"
    echo ""
    cd
    [ ! -f "$TOMATOWARE_PKG" ] && wget -O $TOMATOWARE_PKG $TOMATOWARE_URL
    mkdir -p $TOMATOWARE_DIR
    tar -xzfv $TOMATOWARE_PKG -C $TOMATOWARE_DIR
fi

# Check if /mmc exists and is a symbolic link
if [ ! -L $TOMATOWARE_SYSROOT ]; then
    echo "Tomatoware $TOMATOWARE_SYSROOT is missing or is not a symbolic link."
    echo ""
    sudo ln -sfnv $TOMATOWARE_PATH $TOMATOWARE_SYSROOT
fi

# Check for required Tomatoware tools
if [ ! -x $TOMATOWARE_SYSROOT/bin/gcc ] || [ ! -x $TOMATOWARE_SYSROOT/bin/make ]; then
    echo "ERROR: Tomatoware installation appears incomplete."
    echo "Missing gcc or make in $TOMATOWARE_SYSROOT/bin."
    echo ""
    exit 1
fi

################################################################################
# General

REBUILD_ALL=1
SRC=$TOMATOWARE_SYSROOT/src/smartmontools
mkdir -p $SRC
MAKE="make -j`nproc`"
PATH=$TOMATOWARE_SYSROOT/usr/bin:$TOMATOWARE_SYSROOT/usr/local/sbin:$TOMATOWARE_SYSROOT/usr/local/bin:$TOMATOWARE_SYSROOT/usr/sbin:$TOMATOWARE_SYSROOT/usr/bin:$TOMATOWARE_SYSROOT/sbin:$TOMATOWARE_SYSROOT/bin

################################################################################
# smartmontools-7.5

mkdir -pv "$SRC/smartmontools" && cd "$SRC/smartmontools"
DL="smartmontools-7.5.tar.gz"
FOLDER="${DL%.tar.gz*}"
URL="https://github.com/smartmontools/smartmontools/releases/download/RELEASE_7_5/$DL"

if [ "$REBUILD_ALL" == "1" ]; then
    if [ -f "$FOLDER/Makefile" ]; then
        cd $FOLDER && make uninstall && cd ..
    fi || true
    rm -rfv "$FOLDER"
fi || true

if [ ! -f "$FOLDER/__package_installed" ]; then
    [ ! -f "$DL" ] && wget $URL
    [ ! -d "$FOLDER" ] && tar -xvzf $DL
    cd $FOLDER

    PKG_CONFIG_PATH="$TOMATOWARE_SYSROOT/lib/pkgconfig" \
        ./configure LDFLAGS="-static" --prefix=$TOMATOWARE_SYSROOT

    $MAKE
    make install

    # Stripping removes debug symbols and other metadata, shrinking the size by roughly 80%.
    # The executable programs will still be quite large because of static linking.
    [ -f $TOMATOWARE_SYSROOT/sbin/smartctl ] && strip $TOMATOWARE_SYSROOT/sbin/smartctl
    [ -f $TOMATOWARE_SYSROOT/sbin/smartd ] && strip $TOMATOWARE_SYSROOT/sbin/smartd

    touch __package_installed
fi

