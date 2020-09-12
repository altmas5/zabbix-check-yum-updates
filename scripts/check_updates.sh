i#!/usr/bin/env bash
# From https://github.com/kvz/bash3boilerplate
# Require at least bash 3.x
if [[ "${BASH_VERSINFO[0]}" -lt "3" ]]; then echo "bash version < 3"; exit 1; fi
# Exit on error. Append || true if you expect an error.
set -o errexit
set -o nounset
# Bash will remember and return the highest exit code in a chain of pipes.
set -o pipefail

# script was taken from https://medium.com/caendra-tech/monitoring-system-updates-with-zabbix-7a888510a457
# customized to also use a path to repomd.xml used on FreePBX based on CentOS 7 

timestamp_file="/var/run/zabbix/caendra_check_update"
update_interval="86400" # 1 day
timestamp_file_mtime="0"
os=""
epoch=$(date "+%s")
tmpfile=$(mktemp --tmpdir=/var/run/zabbix)
outfile="/var/run/zabbix/zabbix.count.updates"
function _detectOS {
    if [[ -e /etc/centos-release ]]; then
        export os="centos 6"
    fi
    if [[ -e /etc/centos-release-upstream ]]; then
        export os="centos 7"
    fi
}

function _check_last_update {
    if [[ ! -e $timestamp_file ]]; then 
        export update_needed=y
        touch $timestamp_file
    else
        timestamp_file_mtime=$(stat -c %Y $timestamp_file )
    fi
    if [[ "$((epoch-timestamp_file_mtime))" -gt "$update_interval" ]]; then 
        export update_needed=y
    else
        export update_needed=n
    fi
}

function _check_OS_upgrades {

if [[ "$os" =~ "centos" ]]; then
        if [[ ! -e /var/cache/yum/x86_64/7/sng-base/repomd.xml ]] && [[ ! -e /var/cache/yum/i386/6/base/repomd.xml ]] && [[ ! -e /var/cache/yum/x86_64/6/base/repomd.xml ]]; then
            # if the repomd.xml file does not exists,
            # we assume that this is a new machine 
            # or "yum clean all" was run
            export update_needed="y"
        fi
        if [[ "$update_needed" == "y" ]]; then
            # forced true as the --assumeno option 
            # always returns exit code 1
            yum upgrade --assumeno &> /dev/null || true
            touch $timestamp_file
        fi
        yum_output=$(yum check-update --cacheonly && rc=$? || rc=$?; echo "rc=$rc" > $tmpfile)
        source $tmpfile
        rm $tmpfile
        if [[ "$rc" == "0" ]]; then
            pkg_to_update="0"
        fi
         if [[ "$rc" == "100" ]]; then
            pkg_to_update=$(echo "$yum_output" | egrep -v '^(Load| \*|$)' | wc -l)
        fi
    fi
}

_detectOS
_check_last_update
pkg_to_update=""
_check_OS_upgrades
echo "$pkg_to_update" > $outfile
