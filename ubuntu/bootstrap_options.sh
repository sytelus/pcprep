# Sourced by the Ubuntu bootstrap and its installers, including standalone runs.
export INSTALL_CUDA=${INSTALL_CUDA:-0}
export INSTALL_AZURE_CLI=${INSTALL_AZURE_CLI:-0}
# Desktop, media and hardware packages that a server does not need and that add
# attack surface. prepare_new_vps.sh sets this to 0.
export INSTALL_WORKSTATION_PACKAGES=${INSTALL_WORKSTATION_PACKAGES:-1}

bool_is_true() {
    case "${1:-0}" in
        1|y|Y|yes|YES|true|TRUE|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}
