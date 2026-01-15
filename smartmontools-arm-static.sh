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
CACHED_DIR="${PARENT_DIR}/solartracker-sources"
set -e
set -x

################################################################################
# Helpers

# If autoconf/configure fails due to missing libraries or undefined symbols, you
# immediately see all undefined references without having to manually search config.log
handle_configure_error() {
    local rc=$1

    #grep -R --include="config.log" --color=always "undefined reference" .
    #find . -name "config.log" -exec grep -H "undefined reference" {} \;
    find . -name "config.log" -exec grep -H -E "undefined reference|can't load library|unrecognized command-line option" {} \;

    # Force failure if rc is zero, since error was detected
    [ "${rc}" -eq 0 ] && return 1

    return ${rc}
}

################################################################################
# Package management

# new files:       rw-r--r-- (644)
# new directories: rwxr-xr-x (755)
umask 022

sign_file()
( # BEGIN sub-shell
    [ -n "$1" ]            || return 1

    local target_path="$1"
    local sign_path="$(readlink -f "${target_path}").sign"
    local target_file="$(basename -- "${target_path}")"
    local target_file_hash="$(sha256sum "${target_path}" | awk '{print $1}')"
    local temp_path=""
    local now_localtime="$(date '+%Y-%m-%d %H:%M:%S %Z %z')"

    cleanup() { rm -f "${temp_path}"; }
    trap 'cleanup; exit 130' INT
    trap 'cleanup; exit 143' TERM
    trap 'cleanup' EXIT
    temp_path=$(mktemp "${sign_path}.XXXXXX")
    {
        #printf '%s released %s\n' "${target_file}" "${now_localtime}"
        #printf '\n'
        #printf 'SHA256: %s\n' "${target_file_hash}"
        #printf '\n'
        printf '%s  %s\n' "${target_file_hash}" "${target_file}"
    } >"${temp_path}" || return 1
    touch -r "${target_path}" "${temp_path}" || return 1
    mv -f "${temp_path}" "${sign_path}" || return 1
    # TODO: implement signing
    trap - EXIT INT TERM

    return 0
) # END sub-shell

# Checksum verification for downloaded file
verify_hash() {
    [ -n "$1" ] || return 1

    local file_path="$1"
    local expected="$2"
    local option="$3"
    local actual=""
    local sign_path="$(readlink -f "${file_path}").sign"
    local line=""

    if [ ! -f "${file_path}" ]; then
        echo "ERROR: File not found: ${file_path}"
        return 1
    fi

    if [ -z "${option}" ]; then
        # hash the compressed binary file. this method is best when downloading
        # compressed binary files.
        actual="$(sha256sum "${file_path}" | awk '{print $1}')"
    elif [ "${option}" == "tar_extract" ]; then
        # hash the data, file names, directory names. this method is best when
        # archiving Github repos.
        actual="$(tar -xJOf "${file_path}" | sha256sum | awk '{print $1}')"
    elif [ "${option}" == "xz_extract" ]; then
        # hash the data, file names, directory names, timestamps, permissions, and
        # tar internal structures. this method is not as "future-proof" for archiving
        # Github repos because it is possible that the tar internal structures
        # could change over time as the tar implementations evolve.
        actual="$(xz -dc "${file_path}" | sha256sum | awk '{print $1}')"
    else
        return 1
    fi

    if [ -z "${expected}" ]; then
        if [ ! -f "${sign_path}" ]; then
            echo "ERROR: Signature file not found: ${sign_path}"
            return 1
        else
            # TODO: implement signature verify
            IFS= read -r line <"${sign_path}" || exit 1
            expected=${line%%[[:space:]]*}
            if [ -z "${expected}" ]; then
                echo "ERROR: Bad signature file: ${sign_path}"
                return 1
            fi
        fi
    fi

    if [ "${actual}" != "${expected}" ]; then
        echo "ERROR: SHA256 mismatch for ${file_path}"
        echo "Expected: ${expected}"
        echo "Actual:   ${actual}"
        return 1
    fi

    echo "SHA256 OK: ${file_path}"
    return 0
}

retry() {
    local max=$1
    shift
    local i=1
    while :; do
        if ! "$@"; then
            if [ "${i}" -ge "${max}" ]; then
                return 1
            fi
            i=$((i + 1))
            sleep 10
        else
            return 0
        fi
    done
}

wget_clean() {
    [ -n "$1" ]          || return 1
    [ -n "$2" ]          || return 1
    [ -n "$3" ]          || return 1

    local temp_path="$1"
    local source_url="$2"
    local target_path="$3"

    rm -f "${temp_path}"
    if ! wget -O "${temp_path}" --tries=9 --retry-connrefused --waitretry=5 "${source_url}"; then
        rm -f "${temp_path}"
        return 1
    else
        if ! mv -f "${temp_path}" "${target_path}"; then
            rm -f "${temp_path}" "${target_path}"
            return 1
        fi
    fi

    return 0
}

download()
( # BEGIN sub-shell
    [ -n "$1" ]            || return 1
    [ -n "$2" ]            || return 1
    [ -n "$3" ]            || return 1
    [ -n "${CACHED_DIR}" ] || return 1

    local source_url="$1"
    local source="$2"
    local target_dir="$3"
    local cached_path="${CACHED_DIR}/${source}"
    local target_path="${target_dir}/${source}"
    local temp_path=""

    if [ ! -f "${cached_path}" ]; then
        mkdir -p "${CACHED_DIR}"
        if [ ! -f "${target_path}" ]; then
            cleanup() { rm -f "${cached_path}" "${temp_path}"; }
            trap 'cleanup; exit 130' INT
            trap 'cleanup; exit 143' TERM
            trap 'cleanup' EXIT
            temp_path=$(mktemp "${cached_path}.XXXXXX")
            if ! retry 100 wget_clean "${temp_path}" "${source_url}" "${cached_path}"; then
                return 1
            fi
            trap - EXIT INT TERM
        else
            cleanup() { rm -f "${cached_path}"; }
            trap 'cleanup; exit 130' INT
            trap 'cleanup; exit 143' TERM
            trap 'cleanup' EXIT
            if ! mv -f "${target_path}" "${cached_path}"; then
                return 1
            fi
            trap - EXIT INT TERM
        fi
    fi

    if [ ! -f "${target_path}" ]; then
        if [ -f "${cached_path}" ]; then
            ln -sfn "${cached_path}" "${target_path}"
        fi
    fi

    return 0
) # END sub-shell

clone_github()
( # BEGIN sub-shell
    [ -n "$1" ]            || return 1
    [ -n "$2" ]            || return 1
    [ -n "$3" ]            || return 1
    [ -n "$4" ]            || return 1
    [ -n "$5" ]            || return 1
    [ -n "${CACHED_DIR}" ] || return 1

    local source_url="$1"
    local source_version="$2"
    local source_subdir="$3"
    local source="$4"
    local target_dir="$5"
    local cached_path="${CACHED_DIR}/${source}"
    local target_path="${target_dir}/${source}"
    local temp_path=""
    local temp_dir=""
    local timestamp=""

    if [ ! -f "${cached_path}" ]; then
        umask 022
        mkdir -p "${CACHED_DIR}"
        if [ ! -f "${target_path}" ]; then
            cleanup() { rm -rf "${temp_path}" "${temp_dir}"; }
            trap 'cleanup; exit 130' INT
            trap 'cleanup; exit 143' TERM
            trap 'cleanup' EXIT
            temp_path=$(mktemp "${cached_path}.XXXXXX")
            temp_dir=$(mktemp -d "${target_dir}/temp.XXXXXX")
            mkdir -p "${temp_dir}"
            if ! retry 100 git clone "${source_url}" "${temp_dir}/${source_subdir}"; then
                return 1
            fi
            cd "${temp_dir}/${source_subdir}"
            if ! retry 100 git checkout ${source_version}; then
                return 1
            fi
            if ! retry 100 git submodule update --init --recursive; then
                return 1
            fi
            timestamp="$(git log -1 --format='@%ct')"
            rm -rf .git
            cd ../..
            #chmod -R g-w,o-w "${temp_dir}/${source_subdir}"
            if ! tar --numeric-owner --owner=0 --group=0 --sort=name --mtime="${timestamp}" \
                    -C "${temp_dir}" "${source_subdir}" \
                    -cv | xz -zc -7e -T0 >"${temp_path}"; then
                return 1
            fi
            touch -d "${timestamp}" "${temp_path}" || return 1
            mv -f "${temp_path}" "${cached_path}" || return 1
            rm -rf "${temp_dir}" || return 1
            trap - EXIT INT TERM
            sign_file "${cached_path}"
        else
            cleanup() { rm -f "${cached_path}"; }
            trap 'cleanup; exit 130' INT
            trap 'cleanup; exit 143' TERM
            trap 'cleanup' EXIT
            mv -f "${target_path}" "${cached_path}" || return 1
            trap - EXIT INT TERM
        fi
    fi

    if [ ! -f "${target_path}" ]; then
        if [ -f "${cached_path}" ]; then
            ln -sfn "${cached_path}" "${target_path}"
        fi
    fi

    return 0
) # END sub-shell

download_archive() {
    [ "$#" -eq 3 ] || [ "$#" -eq 5 ] || return 1

    local source_url="$1"
    local source="$2"
    local target_dir="$3"
    local source_version="$4"
    local source_subdir="$5"

    if [ -z "${source_version}" ]; then
        download "${source_url}" "${source}" "${target_dir}"
    else
        clone_github "${source_url}" "${source_version}" "${source_subdir}" "${source}" "${target_dir}"
    fi
}

apply_patch() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local patch_path="$1"
    local target_dir="$2"

    if [ -f "${patch_path}" ]; then
        echo "Applying patch: ${patch_path}"
        if patch --dry-run --silent -p1 -d "${target_dir}/" -i "${patch_path}"; then
            if ! patch -p1 -d "${target_dir}/" -i "${patch_path}"; then
                echo "The patch failed."
                return 1
            fi
        else
            echo "The patch was not applied. Failed dry run."
            return 1
        fi
    else
        echo "Patch not found: ${patch_path}"
        return 1
    fi

    return 0
}

apply_patch_folder() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local patch_dir="$1"
    local target_dir="$2"
    local patch_file=""
    local rc=0

    if [ -d "${patch_dir}" ]; then
        for patch_file in ${patch_dir}/*.patch; do
            if [ -f "${patch_file}" ]; then
                if ! apply_patch "${patch_file}" "${target_dir}"; then
                    rc=1
                fi
            fi
        done
    fi

    return ${rc}
}

rm_safe() {
    [ -n "$1" ] || return 1
    local target_dir="$1"

    # Prevent absolute paths
    case "${target_dir}" in
        /*)
            echo "Refusing to remove absolute path: ${target_dir}"
            return 1
            ;;
    esac

    # Prevent current/parent directories
    case "${target_dir}" in
        "."|".."|*/..|*/.)
            echo "Refusing to remove . or .. or paths containing ..: ${target_dir}"
            return 1
            ;;
    esac

    # Finally, remove safely
    rm -rf -- "${target_dir}"

    return 0
}

apply_patches() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local patch_dir="$1"
    local target_dir="$2"

    if ! apply_patch_folder "${patch_dir}" "${target_dir}"; then
        #rm_safe "${target_dir}"
        return 1
    fi

    return 0
}

extract_package() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local source_path="$1"
    local target_dir="$2"

    case "${source_path}" in
        *.tar.gz|*.tgz)
            tar xzvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar.bz2|*.tbz)
            tar xjvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar.xz|*.txz)
            tar xJvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar.lz|*.tlz)
            tar xlvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar.zst)
            tar xvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar)
            tar xvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *)
            echo "Unsupported archive type: ${source_path}" >&2
            return 1
            ;;
    esac

    return 0
}

unpack_archive()
( # BEGIN sub-shell
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local source_path="$1"
    local target_dir="$2"
    local dir_tmp=""

    if [ ! -d "${target_dir}" ]; then
        cleanup() { rm -rf "${dir_tmp}" "${target_dir}"; }
        trap 'cleanup; exit 130' INT
        trap 'cleanup; exit 143' TERM
        trap 'cleanup' EXIT
        dir_tmp=$(mktemp -d "${target_dir}.XXXXXX")
        mkdir -p "${dir_tmp}"
        if ! extract_package "${source_path}" "${dir_tmp}"; then
            return 1
        else
            # try to rename single sub-directory
            if ! mv -f "${dir_tmp}"/* "${target_dir}"/; then
                # otherwise, move multiple files and sub-directories
                mkdir -p "${target_dir}" || return 1
                mv -f "${dir_tmp}"/* "${target_dir}"/ || return 1
            fi
        fi
        rm -rf "${dir_tmp}" || return 1
        trap - EXIT INT TERM
    fi

    return 0
) # END sub-shell

is_version_git() {
    case "$1" in
        *+git*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

update_patch_library() {
    [ -n "$1" ]            || return 1
    [ -n "$2" ]            || return 1
    [ -n "$3" ]            || return 1
    [ -n "$4" ]            || return 1
    [ -n "${PARENT_DIR}" ] || return 1
    [ -n "${SCRIPT_DIR}" ] || return 1

    local git_commit="$1"
    local patches_dir="$2"
    local pkg_name="$3"
    local pkg_subdir="$4"
    local entware_packages_dir="${PARENT_DIR}/entware-packages"

    if [ ! -d "${entware_packages_dir}" ]; then
        cd "${PARENT_DIR}"
        git clone https://github.com/Entware/entware-packages
    fi

    cd "${entware_packages_dir}"
    git fetch origin
    git reset --hard "${git_commit}"
    [ -d "${patches_dir}" ] || return 1
    mkdir -p "${SCRIPT_DIR}/patches/${pkg_name}/${pkg_subdir}/entware"
    cp -pf "${patches_dir}"/* "${SCRIPT_DIR}/patches/${pkg_name}/${pkg_subdir}/entware/"
    cd ..

    return 0
}

check_static() {
    local rc=0
    for bin in "$@"; do
        echo "Checking ${bin}"
        file "${bin}" || true
        if readelf -d "${bin}" 2>/dev/null | grep NEEDED; then
            rc=1
        fi || true
        ldd "${bin}" 2>&1 || true
    done

    if [ ${rc} -eq 1 ]; then
        echo "*** NOT STATICALLY LINKED ***"
        echo "*** NOT STATICALLY LINKED ***"
        echo "*** NOT STATICALLY LINKED ***"
    fi

    return ${rc}
}

finalize_build() {
    set +x
    echo ""
    echo "Stripping symbols and sections from files..."
    strip -v "$@"

    # Exit here, if the programs are not statically linked.
    # If any binaries are not static, check_static() returns 1
    # set -e will cause the shell to exit here, so renaming won't happen below.
    echo ""
    echo "Checking statically linked programs..."
    check_static "$@"

    # Append ".static" to the program names
    echo ""
    echo "Renaming programs with .static suffix..."
    for bin in "$@"; do
        mv -f "${bin}" "${bin}.static"
    done
    set -x

    return 0
}

################################################################################
# Install the build environment

TOMATOWARE_PKG_SOURCE_URL="https://github.com/lancethepants/tomatoware/releases/download/v5.0/arm-soft-mmc.tgz"
TOMATOWARE_PKG_HASH="ff490819a16f5ddb80ec095342ac005a444b6ebcd3ed982b8879134b2b036fcc"
TOMATOWARE_PKG="arm-soft-mmc-5.0.tgz"
TOMATOWARE_DIR="tomatoware-5.0"
TOMATOWARE_PATH="${PARENT_DIR}/${TOMATOWARE_DIR}"
TOMATOWARE_SYSROOT="/mmc" # or, whatever your tomatoware distribution uses for sysroot

# Check if Tomatoware exists and install it, if needed
if [ ! -d "${TOMATOWARE_PATH}" ]; then
    echo "Tomatoware not found at ${TOMATOWARE_PATH}. Installing..."
    echo ""
    cd ${PARENT_DIR}
    TOMATOWARE_PKG_PATH="${CACHED_DIR}/${TOMATOWARE_PKG}"
    download_archive "${TOMATOWARE_PKG_SOURCE_URL}" "${TOMATOWARE_PKG}" "${CACHED_DIR}"
    verify_hash "${TOMATOWARE_PKG_PATH}" "${TOMATOWARE_PKG_HASH}"
    unpack_archive "${TOMATOWARE_PKG_PATH}" "${TOMATOWARE_DIR}"
fi

# Check if /mmc exists and is a symbolic link
if [ ! -L "${TOMATOWARE_SYSROOT}" ] && ! grep -q " ${TOMATOWARE_SYSROOT} " /proc/mounts; then
    echo "Tomatoware ${TOMATOWARE_SYSROOT} is missing or is not a symbolic link."
    echo ""
    # try making a symlink
    if ! sudo ln -sfn "${TOMATOWARE_PATH}" "${TOMATOWARE_SYSROOT}"; then
        # otherwise, we are probably on a read-only filesystem and
        # the sysroot needs to be already baked into the firmware and
        # not in use by something else.
        # alternatively, you can figure out another sysroot to use.
        mount -o bind "${TOMATOWARE_PATH}" "${TOMATOWARE_SYSROOT}"
    fi
fi

# Check for required Tomatoware tools
if [ ! -x "${TOMATOWARE_SYSROOT}/bin/gcc" ] || [ ! -x "${TOMATOWARE_SYSROOT}/bin/make" ]; then
    echo "ERROR: Tomatoware installation appears incomplete."
    echo "Missing gcc or make in ${TOMATOWARE_SYSROOT}/bin."
    echo ""
    exit 1
fi

# Check shell
if [ "$BASH" != "${TOMATOWARE_SYSROOT}/bin/bash" ]; then
    if [ -z "${TOMATOWARE_SHELL}" ]; then
        export TOMATOWARE_SHELL=1
        exec "${TOMATOWARE_SYSROOT}/bin/bash" "${PATH_CMD}" "$@"
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
REBUILD_ALL=true
SRC="$TOMATOWARE_SYSROOT/src/$PKG_ROOT"
mkdir -p "$SRC"
MAKE="make -j$(grep -c ^processor /proc/cpuinfo)" # parallelism
#MAKE="make -j1"                                  # one job at a time
export PATH="$TOMATOWARE_SYSROOT/usr/bin:$TOMATOWARE_SYSROOT/usr/local/sbin:$TOMATOWARE_SYSROOT/usr/local/bin:$TOMATOWARE_SYSROOT/usr/sbin:$TOMATOWARE_SYSROOT/sbin:$TOMATOWARE_SYSROOT/bin"
export PKG_CONFIG_PATH="$TOMATOWARE_SYSROOT/lib/pkgconfig"
#export PKG_CONFIG="pkg-config --static"

################################################################################
# smartmontools-7.5

PKG_NAME=smartmontools
PKG_VERSION=7.5
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://github.com/smartmontools/smartmontools/releases/download/RELEASE_7_5/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="690b83ca331378da9ea0d9d61008c4b22dde391387b9bbad7f29387f2595f76e"

mkdir -p "${SRC}/${PKG_NAME}" && cd "${SRC}/${PKG_NAME}"

if $REBUILD_ALL; then
    if [ -f "$PKG_SOURCE_SUBDIR/Makefile" ]; then
        cd "$PKG_SOURCE_SUBDIR" && make uninstall && cd ..
    fi
    rm -rf "$PKG_SOURCE_SUBDIR"
fi

if [ ! -f "$PKG_SOURCE_SUBDIR/__package_installed" ]; then
    download "$PKG_SOURCE_URL" "$PKG_SOURCE" "."
    verify_hash "$PKG_SOURCE" "$PKG_HASH"
    unpack_archive "$PKG_SOURCE" "$PKG_SOURCE_SUBDIR"
    cd "$PKG_SOURCE_SUBDIR"

    ./configure \
         LDFLAGS="-static" \
         --prefix="$TOMATOWARE_SYSROOT" \
    || handle_configure_error $?

    $MAKE
    make install

    # strip and verify there are no dependencies for static build
    finalize_build \
        "$TOMATOWARE_SYSROOT/sbin/smartctl" \
        "$TOMATOWARE_SYSROOT/sbin/smartd"

    touch __package_installed
fi

