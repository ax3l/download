#!/bin/bash
#
# To run: curl radia.run | sudo bash -s salt
#
set -e

salt_alarm() {
    local timeout=$1
    timeout=$1
    shift
    bash -c "$@" &
    local op_pid=$!
    {
        sleep "$timeout"
        kill -9 "$op_pid" >& /dev/null
    } &
    local sleep_pid=$!
    wait "$op_pid" >& /dev/null
    local rc=$?
    kill "$sleep_pid" >& /dev/null
    return $rc
}

salt_assert() {
    if (( $UID != 0 )); then
        install_err 'Must run as root'
    fi
    if [[ ! -r /etc/fedora-release ]]; then
        install_err 'Only runs on Fedora'
    fi
    if ! grep -s -q ' 23 ' /etc/fedora-release; then
        install_err 'Only runs on Fedora 23'
    fi
}

salt_bootstrap() {
    install_download http://salt.run \
        | bash -s -- -P -X -N -n ${install_verbose+-D} git develop
}

salt_conf() {
    local d=/etc/salt/minion.d
    mkdir -p "$d"
    install_url biviosoftware/salt-conf srv/salt/minion
    echo "master: $salt_master" > "$d/master.conf"
    install_download bivio.conf > "$d/bivio.conf"
}

salt_main() {
    salt_assert
    salt_master
    umask 022
    salt_pykern
    salt_conf
    salt_bootstrap
    chmod -R go-rwx /etc/salt /var/log/salt /var/cache/salt /var/run/salt
}

salt_master() {
    salt_master=${install_extra_args[0]}
    if [[ -z $salt_master ]]; then
        install_err 'Must supply salt master as extra argument'
    fi
    local res
    res=$(salt_alarm 3 ": < '/dev/tcp/$salt_master/4505'")
    if (( $? != 0 )); then
        install_err "$res$salt_master: is invalid or inaccessible"
    fi
}

salt_pykern() {
    local pip=pip
    if [[ -z $(type -p pip) ]]; then
        pip=pip3
    fi
    # Packages needed by pykern, which is needed by our custom states/modules
    "$pip" install -U pip setuptools pytz docker-py
}

salt_main
