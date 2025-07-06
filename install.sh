#!/bin/bash
# -----------------------------------
# install.sh — orchestrator
# -----------------------------------

LOG_FILE="/var/log/pterodactyl-installer.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log()  { echo "$(date '+%F %T') [INFO]  $1" | tee -a "$LOG_FILE"; }
err()  { echo "$(date '+%F %T') [ERROR] $1" | tee -a "$LOG_FILE"; }

# redirect everything through our logger
exec > >(while read L; do log "$L"; done)
exec 2> >(while read L; do err "$L"; done)

set -e

# Load variables and library
source ./variablesName.txt
source ./lib.sh

print_header "Starting full Pterodactyl install"

# Core prerequisites
update_and_install_packages
configure_timezone
setup_mysql
install_nginx
install_php_fpm_conf
install_daemon
setup_systemd
configure_nginx_ssl

# Now run every installer in installers/
run_installers

reload_services

print_success "All installers completed successfully!"
