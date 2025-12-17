#!/mmc/bin/bash
#############################################################################
# Raspberry Pi build script for:
# smartmontools
#
# This script downloads and compiles all packages needed for adding
# HDD SMART querying capabilities to any ARMv7 device. All you do is run the
# script and copy the resulting executable program to the target platform.
#
# The resulting executable program is statically linked and entirely 
# self-contained, there are no external libraries needed on the target platform.
#
# This script uses the Tomatoware environment.
#
# Tomatoware is a modern, cross-compilation and build environment for ARM-based devices.
# It provides a complete, self-contained toolchain under the /mmc directory,
# including up-to-date compilers, libraries, and build utilities.  
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
# The resulting smartctl and smartd programs are:
#   - Statically linked, requiring no external libraries on the target device.
#   - Self-contained, including drivedb.h and example scripts, all under /mmc.
#   - Ready to be copied to the target platform without any host system dependency.
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
#############################################################################
# Check if Tomatoware directory exists

if [ ! -d "$HOME/tomatoware-5.0" ]; then
    echo "ERROR: Tomatoware not found at $HOME/tomatoware-5.0"
    echo ""
    echo "Please install Tomatoware as follows:"
    echo ""
    echo "  cd ~"
    echo "  wget https://github.com/lancethepants/tomatoware/releases/download/v5.0/arm-soft-mmc.tgz"
    echo "  mkdir -p tomatoware-5.0"
    echo "  tar -xzf arm-soft-mmc.tgz -C tomatoware-5.0"
    echo ""
    exit 1
fi

# Check if /mmc exists and is a symbolic link
if [ ! -L /mmc ]; then
    echo "ERROR: /mmc is missing or is not a symbolic link."
    echo ""
    echo "Tomatoware must be available at /mmc."
    echo "Create the symbolic link as follows:"
    echo ""
    echo "  sudo ln -sfn \$HOME/tomatoware-5.0 /mmc"
    echo ""
    exit 1
fi

# Check for required Tomatoware tools
if [ ! -x /mmc/bin/gcc ] || [ ! -x /mmc/bin/make ]; then
    echo "ERROR: Tomatoware installation appears incomplete."
    echo "Missing gcc or make in /mmc/bin."
    echo ""
    exit 1
fi

#############################################################################
# Setup

PATH_CMD="$(readlink -f $0)"
set -e
set -x

REBUILD_ALL=1
SRC=/mmc/src/smartmontools
mkdir -p $SRC
MAKE="make -j`nproc`"
PATH=/mmc/usr/bin:/mmc/usr/local/sbin:/mmc/usr/local/bin:/mmc/usr/sbin:/mmc/usr/bin:/mmc/sbin:/mmc/bin

#############################################################################
# smartmontools-7.5

mkdir -p "$SRC/smartmontools" && cd "$SRC/smartmontools"
DL="smartmontools-7.5.tar.gz"
FOLDER="${DL%.tar.gz*}"
URL="https://github.com/smartmontools/smartmontools/releases/download/RELEASE_7_5/$DL"
[ "$REBUILD_ALL" == "1" ] && rm -rf "$FOLDER"
if [ ! -f "$FOLDER/__package_installed" ]; then
    [ ! -f "$DL" ] && wget $URL
    [ ! -d "$FOLDER" ] && tar xvzf $DL
    cd $FOLDER

    PKG_CONFIG_PATH="/mmc/lib/pkgconfig" \
    ./configure \
    LDFLAGS="-static" \
    --prefix=/mmc

    $MAKE
    make install

    # Stripping removes debug symbols and other metadata, shrinking the size by roughly 80%.
    # The executable programs will still be quite large because of static linking.
    [ -f /mmc/sbin/smartctl ] && strip /mmc/sbin/smartctl
    [ -f /mmc/sbin/smartd ] && strip /mmc/sbin/smartd

    touch __package_installed
fi

