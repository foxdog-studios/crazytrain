# =============================================================================
# = Configuration                                                             =
# =============================================================================

REPO=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/../..")

ENV=$REPO/env

NODE_GLOBAL_PACKAGES=(
    'bower'
    'meteorite'
    'grunt-cli'
)

PYTHON_PACKAGES=(
    'fabric==1.8.0'
    'git+git://github.com/foxdog-studios/conf.git@v2.0.1'
)

PYTHON_VERSION=2.7

SYSTEM_PACKAGES=(
    'git'
    'nodejs'
    'python2-virtualenv'
    'yaourt'
)


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

add_archlinuxfr_repo() {
    if ! grep -q '\[archlinuxfr\]' /etc/pacman.conf; then
        sudo tee -a /etc/pacman.conf <<EOF
[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/\$arch
EOF
    fi
}

create_ve() {
    "virtualenv-$PYTHON_VERSION" "$ENV"
}

install_global_node_packages() {
    sudo npm install --global "${NODE_GLOBAL_PACKAGES[@]}"
}

install_node_packages() {
    npm install
}

install_python_packages() {
    _ve _install_python_packages
}

_install_python_packages() {
    local package
    for package in "${PYTHON_PACKAGES[@]}"; do
        pip install "$package"
    done
}

install_system_packages() {
    sudo pacman --needed --noconfirm --refresh --sync "${SYSTEM_PACKAGES[@]}"
}


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

_allow_unset() {
    local restore=$(set +o | grep nounset)
    set +o nounset
    "${@}"
    local exit_status=$?
    $restore
    return $exit_status
}

_ve() {
    _allow_unset source "$ENV/bin/activate"
    "${@}"
    _allow_unset deactivate
}

