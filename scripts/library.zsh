# ==============================================================================
# = Paths                                                                      =
# ==============================================================================

repo=${$(realpath $0):h:h}

config_default=$repo/config/default.json
env=$repo/env

if (( ! $+CRAZY_TRAINS_CONF )); then
    export CRAZY_TRAINS_CONF=$config_default
fi

# ==============================================================================
# = Virtual environment                                                        =
# ==============================================================================

if [[ -d $env ]]; then
    function active_virtual_env()
    {
        setopt local_options
        unsetopt no_unset

        source $env/bin/activate
    }

    active_virtual_env
    unfunction active_virtual_env
fi

