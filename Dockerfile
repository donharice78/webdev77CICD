# Stage 1: PHP Composer Builder
FROM composer:2 as builder

WORKDIR /app

# 1. Install system dependencies with version pinning
RUN apk add --no-cache --update \
    git=~2 \
    unzip=~6 \
    bash=~5 \
    libzip-dev=~1 \
    icu-dev=~72 \
    libxml2-dev=~2 \
    postgresql-dev=~15 \
    linux-headers=~6 \
    freetype-dev=~2 \
    libjpeg-turbo-dev=~2 \
    libpng-dev=~1 \
    oniguruma-dev=~6

# 2. Install and configure PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-configure intl && \
    docker-php-ext-install -j$(nproc) \
    zip \
    intl \
    xml \
    pdo_mysql \
    mbstring \
    opcache \
    gd

# 3. Configure Composer environment
ENV COMPOSER_MEMORY_LIMIT=-1 \
    COMPOSER_NO_INTERACTION=1 \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

# 4. Copy only composer files first
COPY composer.* symfony.lock ./

# 5. Robust composer install with verification
RUN set -ex; \
    \
    # First attempt with verbose output
    composer install \
    --no-dev \
    --optimize-autoloader \
    --no-progress \
    --prefer-dist \
    --ignore-platform-reqs \
    --ansi || \
    \
    # Fallback if first attempt fails
    (echo "First attempt failed. Cleaning cache and retrying..." && \
    composer clear-cache && \
    rm -rf vendor/* && \
    composer install \
    --no-dev \
    --optimize-autoloader \
    --no-progress \
    --prefer-dist \
    --ignore-platform-reqs \
    --ansi); \
    \
    # Final verification
    if [ ! -f "vendor/autoload.php" ]; then \
        echo "ERROR: Composer installation failed completely"; \
        exit 1; \
    fi

# 6. Copy application files
COPY . .

# 7. Run post-install scripts
RUN set -ex; \
    composer dump-autoload --optimize --classmap-authoritative; \
    if [ -f bin/console ]; then \
        php bin/console cache:clear --no-warmup || echo "Cache clear failed but continuing"; \
        php bin/console assets:install public || echo "Assets install failed but continuing"; \
    fi

# Stage 2: Node.js Builder (conditional)
FROM node:18-alpine as node_builder

WORKDIR /app
COPY --from=builder /app .

# Only run if package.json exists
RUN if [ -f package.json ]; then \
    apk add --no-cache --virtual .build-deps \
        python3 \
        make \
        g++; \
    npm config set update-notifier false; \
    npm install --no-audit --progress=false; \
    if grep -q '"build"' package.json; then \
        npm run build || echo "Build script failed but continuing"; \
    fi; \
    apk del .build-deps; \
    rm -rf /tmp/* /var/cache/apk/* ~/.npm; \
    fi

# Stage 3: Production Runtime
FROM php:8.2-fpm-alpine

# 1. Install runtime dependencies
RUN apk add --no-cache \
    nginx=~1 \
    supervisor=~4 \
    libzip=~1 \
    libpng=~1 \
    libjpeg-turbo=~2 \
    freetype=~2 \
    libxml2=~2 \
    oniguruma=~6 \
    icu=~72 \
    postgresql-libs=~15 \
    acl=~2 \
    fcgi=~2 \
    shadow=~4

# 2. Install and configure PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    pdo_pgsql \
    zip \
    intl \
    xml \
    mbstring \
    opcache \
    pcntl \
    gd && \
    pecl install redis && docker-php-ext-enable redis

# 3. Configure PHP
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.interned_strings_buffer=8" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "opcache.max_accelerated_files=4000" >> /usr/local/etc/php/conf.d/opcache.ini && \
    echo "realpath_cache_size=4096K" >> /usr/local/etc/php/conf.d/php.ini && \
    echo "realpath_cache_ttl=600" >> /usr/local/etc/php/conf.d/php.ini

# 4. Configure nginx
RUN mkdir -p /run/nginx /var/log/nginx && \
    touch /var/log/nginx/access.log /var/log/nginx/error.log && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/symfony.conf /etc/nginx/conf.d/default.conf

# 5. Configure supervisor
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 6. Application setup
WORKDIR /var/www/html

COPY --from=builder /app .
COPY --from=node_builder /app/public/build public/build/ 2>/dev/null || :

# 7. Set up permissions
RUN set -ex; \
    mkdir -p var/cache var/log public/uploads; \
    chown -R www-data:www-data var public; \
    find var public -type d -exec chmod 775 {} \; && \
    find var public -type f -exec chmod 664 {} \; && \
    chmod +x bin/console

# 8. Healthcheck and entrypoint
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s \
    CMD curl -f http://localhost/healthz || exit 1

COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]