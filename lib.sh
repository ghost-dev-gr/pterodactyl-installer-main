#!/bin/bash

print_header() {
    echo -e "\n==== $1 ====\n"
}

print_success() {
    echo -e "\n✔️  $1\n"
}


update_and_install_packages() {
    print_header "Updating system and installing packages"
    apt update && apt upgrade -y
    apt install -y curl wget tar unzip git nginx mysql-server php php-cli php-fpm php-mysql \
        php-zip php-gd php-mbstring php-curl php-xml php-bcmath php-tokenizer php-common php-memcached \
        php-redis php-imagick php-opcache php-pdo unzip curl supervisor
}

configure_timezone() {
    print_header "Configuring timezone to $TIMEZONE"
    timedatectl set-timezone "$TIMEZONE"
}

install_dependencies() {
    print_header "Installing dependencies"
    apt install -y software-properties-common gnupg
    add-apt-repository ppa:ondrej/php -y
    apt update
}

setup_mysql() {
    print_header "Setting up MySQL database"

    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DB};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
}

install_nginx() {
    print_header "Installing NGINX"
    systemctl enable nginx
}

install_php() {
    print_header "Installing PHP configurations"
    cp configs/www-pterodactyl.conf /etc/php/8.1/fpm/pool.d/www-pterodactyl.conf
    systemctl restart php8.1-fpm
}

install_panel() {
    print_header "Installing Pterodactyl panel"
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl

    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache

    cp .env.example .env

    composer install --no-dev --optimize-autoloader

    php artisan key:generate --force
    php artisan p:environment:setup --email="$ADMIN_EMAIL" --timezone="$TIMEZONE" --url="https://$FQDN"
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database="$MYSQL_DB" --username="$MYSQL_USER" --password="$MYSQL_PASSWORD"
    php artisan migrate --seed --force
    php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USERNAME" --name-first="$ADMIN_FIRSTNAME" --name-last="$ADMIN_LASTNAME" --password="$ADMIN_PASSWORD" --admin=1

    chown -R www-data:www-data /var/www/pterodactyl
}

install_daemon() {
    print_header "Installing Wings Daemon"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    systemctl enable docker && systemctl start docker

    curl -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings

    mkdir -p /etc/pterodactyl
    wings configure --token "YOUR_WINGS_TOKEN_HERE"  # you must automate this later
}

setup_systemd() {
    print_header "Setting up systemd services"
    cp configs/pteroq.service /etc/systemd/system/pteroq.service
    cp configs/wings.service /etc/systemd/system/wings.service

    systemctl daemon-reexec
    systemctl enable --now pteroq
    systemctl enable --now wings
}

configure_nginx() {
    print_header "Configuring NGINX for SSL"

    domain="$FQDN"
    nginx_conf="configs/nginx.conf"
    ssl_conf="configs/nginx_ssl.conf"
    
    mkdir -p /etc/ssl
    cp "$nginx_conf" "/etc/nginx/sites-available/pterodactyl.conf"
    sed -i "s|<domain>|$domain|g" "/etc/nginx/sites-available/pterodactyl.conf"
    sed -i "s|<php_socket>|/var/run/php/php8.1-fpm.sock|g" "/etc/nginx/sites-available/pterodactyl.conf"
    ln -sfn /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf

    # Same for SSL template
    cp "$ssl_conf" "/etc/nginx/sites-available/pterodactyl-ssl.conf"
    sed -i "s|<domain>|$domain|g" "/etc/nginx/sites-available/pterodactyl-ssl.conf"
    sed -i "s|<php_socket>|/var/run/php/php8.1-fpm.sock|g" "/etc/nginx/sites-available/pterodactyl-ssl.conf"

    # You should already have certs at /etc/ssl/<domain>.pem and .key
    nginx -t && systemctl reload nginx
}

reload_services() {
    print_header "Reloading all services"
    systemctl restart nginx
    systemctl restart php8.1-fpm
    systemctl restart pteroq
    systemctl restart wings
}
