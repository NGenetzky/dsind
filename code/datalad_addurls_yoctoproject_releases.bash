#!/bin/bash
#
# csv format example:
################################################################################
# name,yocto_version,url
# poky-glibc-x86_64-core-image-minimal-aarch64-toolchain-ext-2.6.4.sh,yocto-2.6.4,http://downloads.yoctoproject.org/releases/yocto/yocto-2.6.4/toolchain/x86_64/poky-glibc-x86_64-core-image-minimal-aarch64-toolchain-ext-2.6.4.sh
# poky-glibc-x86_64-core-image-minimal-aarch64-toolchain-ext-2.6.4.sh.md5sum,yocto-2.6.4,http://downloads.yoctoproject.org/releases/yocto/yocto-2.6.4/toolchain/x86_64/poky-glibc-x86_64-core-image-minimal-aarch64-toolchain-ext-2.6.4.sh.md5sum
################################################################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Bash Strict Mode
    set -eu -o pipefail
    IFS=$'\n\t'
fi

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REL_TO_BASE="./../../"
DEST="./"
readonly \
    BASE_DIR \
    REL_TO_BASE \
    DEST

datalad_addurls_yoctoproject_releases(){
    csv_file="${1?}"

    # Work from base of dataset
    cd "${BASE_DIR}/${REL_TO_BASE}"

    [[ -f "${csv_file}" ]] || exit 1
    
    # NOTE: "version" appears to be a monotonically increasing.
    datalad addurls \
        "${csv_file}" \
        '{url}' \
        "{name}" || true
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    datalad_addurls_yoctoproject_releases "$@"
fi
