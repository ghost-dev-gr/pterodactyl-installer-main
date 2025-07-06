#!/bin/bash
# -----------------------------------
# panel.sh — just the Panel portion
# -----------------------------------

set -e
source ../variablesName.txt
source ../lib.sh

print_header "Installing Pterodactyl Panel"

# 1. Download & extract panel
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz \
     https://github.com/ghost-dev-gr/panel/releases/latest/download/panel.tar.gz
tar -xzf panel.tar.gz && rm panel.tar.gz

# 2. Permissions
chmod -R 755 storage bootstrap/cache
chown -R www-data:www-data .

# 3. Composer & env
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
cp .env.example .env
composer install --no-dev --optimize-autoloader

# 4. Artisan setup
php artisan key:generate --force
php artisan p:environment:setup \
    --email="$ADMIN_EMAIL" \
    --timezone="$TIMEZONE" \
    --url="https://$FQDN"
php artisan p:environment:database \
    --host=127.0.0.1 --port=3306 \
    --database="$MYSQL_DB" --username="$MYSQL_USER" \
    --password="$MYSQL_PASSWORD"
php artisan migrate --seed --force

# 5. Create admin user
php artisan p:user:make \
    --email="$ADMIN_EMAIL" \
    --username="$ADMIN_USERNAME" \
    --name-first="$ADMIN_FIRSTNAME" \
    --name-last="$ADMIN_LASTNAME" \
    --password="$ADMIN_PASSWORD" \
    --admin=1

# 6. Final perms & restart
chown -R www-data:www-data .
chmod -R 755 storage bootstrap/cache
reload_services

print_success "Pterodactyl Panel installed!"
