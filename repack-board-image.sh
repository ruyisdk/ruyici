#!/usr/bin/env bash

set -e

_LO_MOUNT=
_STAGING_DIR=

_cleanup() {
    if [[ -n $_STAGING_DIR ]]; then
        if sudo umount "$_STAGING_DIR" > /dev/null 2>&1; then
            echo "[+] un-mounted $_STAGING_DIR"
        else
            echo "[.] $_STAGING_DIR is not mounted"
        fi

        if rmdir "$_STAGING_DIR"; then
            echo "[+] removed $_STAGING_DIR"
        else
            echo "[-] failed to remove $_STAGING_DIR"
        fi
    fi

    if [[ -n $_LO_MOUNT ]]; then
        if sudo losetup -d "$_LO_MOUNT"; then
            echo "[+] detached $_LO_MOUNT"
        else
            echo "[-] failed to detach $_LO_MOUNT"
        fi
    fi
}

_is_readonly_fstype() {
    case "$1" in
    cramfs|erofs|romfs|squashfs)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

_inject_into() {
    local dest="$1"
    local line="$2"

    if echo "$line" | sudo tee -a "$dest" > /dev/null; then
        echo "[+]     $dest"
    else
        echo "[-]     $dest"
        return 1
    fi
}

inject_ruyisdk_credentials() {
    local workdir="$1"

    # based on result of the following commands:
    #
    # useradd -m -c "RuyiSDK well-known credential" -u 11111 -U ruyisdk
    # passwd ruyisdk  # password is "ruyisdk" (minus the quotes)
    local uid=11111
    local gid=11111
    local home_dir_rel="home/ruyisdk"
    local group_record="ruyisdk:x:${gid}:"
    local gshadow_record='ruyisdk:!::'
    local passwd_record="ruyisdk:x:${uid}:${gid}:RuyiSDK well-known credential:/${home_dir_rel}:/bin/sh"
    # shellcheck disable=SC2016
    local shadow_record='ruyisdk:$y$j9T$TWVa6ERvzmT9LnGHf6Acz.$t77z2.nrvWVbubNVo/if12l1qwy7rQ1mWCkaylS3cA1:19979:0:99999:7:::'

    echo "[.]   injecting RuyiSDK well-known credential"
    pushd "$workdir" > /dev/null
    _inject_into etc/group "$group_record"
    _inject_into etc/gshadow "$gshadow_record"
    _inject_into etc/passwd "$passwd_record"
    _inject_into etc/shadow "$shadow_record"

    sudo mkdir -p home/ruyisdk
    sudo chown "$uid:$gid" home/ruyisdk
    echo "[+]     created home directory"

    popd > /dev/null
}

_maybe_fsck() {
    local dev="$1"
    local fstype="$2"
    case "$fstype" in
    ext*)
        sudo e2fsck -p "$dev" > /dev/null
        echo "[+]   e2fsck-ed $dev"
        ;;
    esac
}

main() {
    if [[ $# -ne 2 ]]; then
        echo "usage: $0 <src image> <dst image>" >&2
        return 1
    fi

    local src_image="$1"
    local dst_image="$2"

    echo "[+] copying $src_image to $dst_image"
    cp --reflink=auto "$src_image" "$dst_image"

    _LO_MOUNT="$(sudo losetup -f -P --show "$dst_image")"
    echo "[+] loop-mounted image to $_LO_MOUNT"

    _STAGING_DIR="$(mktemp -d)"
    echo "[+] using $_STAGING_DIR as staging mountpoint directory"

    local lo_has_partitions=true
    local lo_dev
    local fstype
    for lo_dev in "$_LO_MOUNT"p* "$_LO_MOUNT"; do
        # account for the failed pathname expansion (no recognized partition
        # table in the image) case
        if [[ $lo_dev == "${_LO_MOUNT}p*" ]]; then
            echo "[.] the local system did not see partitions in $_LO_MOUNT"
            lo_has_partitions=false
            continue
        fi

        if [[ $lo_dev == "$_LO_MOUNT" ]] && "$lo_has_partitions"; then
            # the loop device has partitions and we have already checked all
            # of them
            break
        fi

        echo "[.] trying $lo_dev"
        fstype="$(lsblk -l -n --output=fstype "$lo_dev")"
        echo "[.]   fstype is $fstype"

        if _is_readonly_fstype "$fstype"; then
            # TODO: implement a copy-then-repack procedure for these fs's
            echo "[.]   support for read-only filesystems is TODO"
            continue
        fi

        _maybe_fsck "$lo_dev" "$fstype"

        if ! sudo mount "$lo_dev" "$_STAGING_DIR" > /dev/null; then
            echo "[.]   failed to mount $lo_dev"
            continue
        fi

        if ! [[ -e "$_STAGING_DIR/etc/passwd" ]]; then
            echo "[.]   $lo_dev does not contain /etc/passwd"
            sudo umount "$_STAGING_DIR"
            continue
        fi

        echo "[+]   $lo_dev contains /etc/passwd"
        inject_ruyisdk_credentials "$_STAGING_DIR"

        sudo umount "$_STAGING_DIR"

        _maybe_fsck "$lo_dev" "$fstype"
    done
}

trap _cleanup EXIT
main "$@"
