# Stage 1: PHP Composer Builder
FROM composer:2 as builder

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    git \
    unzip \
    libzip-dev \
    icu-dev \
    libxml2-dev \
    postgresql-dev \
    linux-headers

# Install required PHP extensions
RUN docker-php-ext-install \
    zip \
    intl \
    xml \
    pdo_mysql

# Configure environment
ENV COMPOSER_MEMORY_LIMIT=-1 \
    COMPOSER_NO_INTERACTION=1

# Copy only composer files first for layer caching
COPY composer.* symfony.lock ./

# Install dependencies with retry logic
RUN set -e; \
    composer install \
    --no-dev \
    --optimize-autoloader \
    --ignore-platform-reqs \
    --prefer-dist || \
    (echo "First attempt failed. Retrying..." && \
    rm -rf vendor/* && \
    composer install \
    --no-dev \
    --optimize-autoloader \
    --ignore-platform-reqs \
    --prefer-dist)

# Copy application files
COPY . .

# Run post-install scripts
RUN set -e; \
    composer dump-autoload --optimize --classmap-authoritative; \
    if [ -f bin/console ]; then \
        composer run-script post-install-cmd || \
        (echo "Warning: post-install scripts failed but continuing build"; exit 0); \
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
    npm install --no-audit --progress=false; \
    if grep -q '"build"' package.json; then \
        npm run build || echo "Build script failed but continuing"; \
    fi; \
    apk del .build-deps; \
    rm -rf /tmp/* /var/cache/apk/* ~/.npm; \
    fi

# Stage 3: Production Runtime
FROM php:8.2-fpm-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    acl \
    fcgi \
    nginx \
    supervisor \
    libzip \
    libpng \
    libjpeg-turbo \
    freetype \
    libxml2 \
    oniguruma \
    icu \
    postgresql-libs

# Install build dependencies and PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    g++ \
    libtool \
    make \
    pcre-dev \
    linux-headers \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libxml2-dev \
    oniguruma-dev \
    icu-dev \
    postgresql-dev && \
    docker-php-ext-install \
    pdo_mysql \
    pdo_pgsql \
    zip \
    intl \
    xml \
    mbstring \
    opcache \
    pcntl && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd && \
    pecl install redis && docker-php-ext-enable redis && \
    apk del .build-deps && \
    rm -rf /tmp/* /var/cache/apk/* /usr/src/php/ext/*

# Configure PHP
RUN mkdir -p /usr/local/etc/php/conf.d && \
    { \
        echo 'opcache.enable=1'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
    } > /usr/local/etc/php/conf.d/opcache.ini

# Configure nginx
RUN mkdir -p /run/nginx /var/log/nginx && \
    touch /var/log/nginx/access.log /var/log/nginx/error.log
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/symfony.conf /etc/nginx/conf.d/default.conf

# Configure supervisor
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Application setup
WORKDIR /var/www/html

# Copy application from builder stages
COPY --from=builder /app .
COPY --from=node_builder /app/public/build public/build/ 2>/dev/null || :

# Create required directories
RUN mkdir -p var/cache var/log public/uploads

# Set permissions (safer approach)
RUN chown -R www-data:www-data var public && \
    find var public -type d -exec chmod 775 {} \; && \
    find var public -type f -exec chmod 664 {} \;

# Entrypoint and healthcheck
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s \
    CMD curl -f http://localhost/ping || exit 1

ENTRYPOINT ["docker-entrypoint"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]