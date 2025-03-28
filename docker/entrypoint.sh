#!/bin/sh

set -e

# Install dependencies only if needed
if [ ! -f "vendor/autoload_runtime.php" ]; then
    composer install --prefer-dist --no-progress --no-interaction
fi

# Generate APP_SECRET if not set
if [ -z "$APP_SECRET" ]; then
    APP_SECRET=$(openssl rand -hex 32)
    export APP_SECRET
fi

# Clear cache
if [ "$APP_ENV" != "prod" ]; then
    php bin/console cache:clear
fi

# Execute migrations
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration

exec "$@"