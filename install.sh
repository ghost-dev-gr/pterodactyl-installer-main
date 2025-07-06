#!/bin/bash
echo "install.sh runned"
LOG_FILE="/var/log/pterodactyl-installer.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
    echo "$(date '+%F %T') [$1] $2" | tee -a "$LOG_FILE"
}

exec > >(while read line; do log "INFO" "$line"; done)
exec 2> >(while read line; do log "ERROR" "$line"; done)

set -e
source ../variablesName.txt
source "$(dirname "$0")/lib.sh"

print_header "Pterodactyl Installer Started"


set -e
source ../variablesName.txt
source "$(dirname "$0")/lib.sh"

print_header "Pterodactyl Installer Started"

update_and_install_packages
configure_timezone
install_dependencies
setup_mysql
install_nginx
install_php
install_panel
install_daemon
setup_systemd
configure_nginx
reload_services

print_success "Pterodactyl successfully installed!"
