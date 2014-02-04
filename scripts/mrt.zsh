#!/usr/bin/env zsh

setopt err_exit

repo=${0:h}/..

if [[ $# -eq 0 ]]; then
    args=( --settings "$PUNISHER_CONFIG" )
else
    args=( "$@" )
fi

cd "$repo/meteor"
exec mrt "${args[@]}"

