# Stage 1: Composer - Dependency Installation
FROM composer:2.7 as builder

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    git \
    unzip \
    libzip-dev

# Install PHP extensions needed for composer
RUN docker-php-ext-install zip

# Copy only composer files first for optimal caching
COPY composer.json composer.lock symfony.lock ./

# Install dependencies (no dev dependencies)
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --ignore-platform-reqs

# Copy all files and complete installation
COPY . .
RUN composer dump-autoload --optimize --no-dev --classmap-authoritative && \
    composer run-script --no-dev post-install-cmd

# Stage 2: Node - Frontend Assets
FROM node:18-alpine as node_builder

WORKDIR /app
COPY --from=builder /app .

# Install and build assets if package.json exists
RUN if [ -f package.json ]; then \
    apk add --no-cache --virtual .build-deps python3 make g++ && \
    npm install && \
    npm run build && \
    apk del .build-deps; \
    fi

# Stage 3: Production Image
FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

# Install runtime dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    libzip \
    libpng \
    libjpeg-turbo \
    libxml2 \
    icu

# Install build dependencies and PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libxml2-dev \
    icu-dev \
    linux-headers && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    gd \
    pdo_mysql \
    zip \
    opcache \
    intl && \
    pecl install redis && docker-php-ext-enable redis && \
    apk del .build-deps && \
    rm -rf /tmp/* /var/cache/apk/*

# Configure PHP
COPY docker/php/conf.d/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf

# Configure nginx
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/symfony.conf /etc/nginx/conf.d/default.conf

# Configure supervisor
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy application
COPY --from=builder /app .
COPY --from=node_builder /app/public/build public/build/

# Set up permissions
RUN mkdir -p var/cache var/log public && \
    chown -R www-data:www-data var public && \
    chmod -R 775 var public

# Runtime configuration
COPY docker/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s \
    CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]