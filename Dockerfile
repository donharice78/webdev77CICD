# Stage 1: PHP Composer
FROM composer:2 as builder

WORKDIR /app

# Minimal system deps
RUN apk add --no-cache git unzip libzip-dev

# Install only required PHP extension
RUN docker-php-ext-install zip

# Copy only what's needed for composer first
COPY composer.* symfony.lock ./

# Install with scripts (required for Doctrine)
RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction \
    --ignore-platform-reqs

# Copy rest of application
COPY . .

# Stage 2: Node.js (conditional)
FROM node:18-alpine as node_builder
WORKDIR /app
COPY --from=builder /app .

# Only run if package.json exists
RUN if [ -f package.json ]; then \
    apk add --no-cache --virtual .build-deps python3 make g++; \
    npm install --no-audit --progress=false; \
    [ -f "webpack.config.js" ] && npm run build; \
    apk del .build-deps; \
    rm -rf /tmp/* /var/cache/apk/* ~/.npm; \
    fi

# Stage 3: Production
FROM php:8.2-fpm-alpine

# Install runtime deps (grouped logically)
RUN apk add --no-cache \
    # System tools
    acl fcgi nginx supervisor \
    # PHP extension dependencies
    libzip libpng libjpeg-turbo freetype libxml2 oniguruma icu

# Install build deps, PHP extensions, then remove build deps
RUN apk add --no-cache --virtual .build-deps \
    autoconf g++ libtool make pcre-dev linux-headers \
    libzip-dev libpng-dev libjpeg-turbo-dev freetype-dev \
    libxml2-dev oniguruma-dev icu-dev && \
    docker-php-ext-install \
    pdo_mysql zip mbstring xml intl opcache && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd && \
    pecl install -o -f redis && docker-php-ext-enable redis && \
    apk del .build-deps && \
    rm -rf /tmp/* /var/cache/apk/* /usr/src/php/ext/*

# Application setup
WORKDIR /var/www/html

# Copy application
COPY --from=builder /app .
COPY --from=node_builder /app/public/build public/build/ 2>/dev/null || :

# Configurations
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/symfony.conf /etc/nginx/conf.d/default.conf
COPY docker/php/conf.d/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Create required directories
RUN mkdir -p var/cache var/log public /run/nginx /var/log/nginx && \
    touch /var/log/nginx/access.log /var/log/nginx/error.log

# Set permissions safely
RUN find var public -type d -exec chmod 775 {} \; && \
    find var public -type f -exec chmod 664 {} \; && \
    chown -R www-data:www-data var public

# Entrypoint and healthcheck
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s \
    CMD curl -f http://localhost/ping || exit 1

ENTRYPOINT ["docker-entrypoint"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]