#!/bin/bash
# Create a new user that can easily be referenced

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Bash Strict Mode
    set -eu -o pipefail
    IFS=$'\n\t'
fi

# config
_HOST_DOMAIN='genetzky.us'

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly \
    BASE_DIR \
    _HOST_DOMAIN \
    _USER_PREFIX

dsind_new_user(){
    T0="$(date --iso-8601=d)"
    uuid="$(uuidgen -t)"
    uuid_short="$(echo "${uuid}" | cut -c1-8)"
    host="$(hostname)"
    name="dsind ${host} ${uuid_short}"

    printf 'T0="%s"\nUUID="%s"\nNAME="%s"\nEMAIL="%s"\n' \
        "${T0}" \
        "${uuid}" \
        "${name}" \
        "dsind.${host}.${uuid}@${_HOST_DOMAIN}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    dsind_new_user "$@"
fi