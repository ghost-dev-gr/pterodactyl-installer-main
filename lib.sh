#!/bin/bash
# -----------------------------------
# lib.sh — shared helper functions
# -----------------------------------

lib_loaded() { :; }

print_header() {
    echo -e "\n==== $1 ====\n"
}

print_success() {
    echo -e "\n✔️  $1\n"
}

block_apache() {
    cat <<EOF > /etc/apt/preferences.d/no-apache
Package: apache2*
Pin: release *
Pin-Priority: -1
EOF
}

update_and_install_packages() {
    print_header "Updating & installing base packages"
    block_apache
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get -y -o Dpkg::Options::="--force-confdef" \
              -o Dpkg::Options::="--force-confold" upgrade
    apt-get install -y curl wget tar unzip git nginx mysql-server \
        php8.1-fpm php8.1-cli php8.1-mysql php-zip php-gd php-mbstring \
        php-curl php-xml php-bcmath php-tokenizer php-common php-memcached \
        php-redis php-imagick php-opcache supervisor
}

configure_timezone() {
    print_header "Setting timezone to $TIMEZONE"
    timedatectl set-timezone "$TIMEZONE"
}

setup_mysql() {
    print_header "Configuring MySQL"
    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DB};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
}

install_nginx() {
    print_header "Enabling NGINX"
    systemctl enable --now nginx
}

install_php_fpm_conf() {
    print_header "Deploying PHP-FPM pool config"
    cp configs/www-pterodactyl.conf /etc/php/8.1/fpm/pool.d/www-pterodactyl.conf
    systemctl restart php8.1-fpm
}

install_daemon() {
    print_header "Installing Wings daemon"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    systemctl enable --now docker
    curl -o /usr/local/bin/wings \
      https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings
    mkdir -p /etc/pterodactyl
    wings configure --token "$WINGS_TOKEN"
}

setup_systemd() {
    print_header "Installing systemd services"
    cp configs/pteroq.service /etc/systemd/system/pteroq.service
    cp configs/wings.service /etc/systemd/system/wings.service
    systemctl daemon-reexec
    systemctl enable --now pteroq wings
}

configure_nginx_ssl() {
    print_header "Configuring NGINX site"
    local domain="$FQDN"
    cp configs/nginx.conf /etc/nginx/sites-available/pterodactyl.conf
    sed -i "s|<domain>|$domain|g" /etc/nginx/sites-available/pterodactyl.conf
    sed -i "s|<php_socket>|/var/run/php/php8.1-fpm.sock|g" /etc/nginx/sites-available/pterodactyl.conf
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
}

# Discover & run all *.sh in installers/
run_installers() {
    print_header "Running installer scripts in installers/"
    for script in installers/*.sh; do
        [ -x "$script" ] || chmod +x "$script"
        print_header "→ Executing $script"
        "$script"
    done
}

reload_services() {
    print_header "Reloading all services"
    systemctl restart nginx php8.1-fpm mysql pteroq wings
}
