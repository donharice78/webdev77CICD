# Stage 1: Build stage
FROM composer:2 as builder

WORKDIR /app

# Install system dependencies for composer
RUN apk add --no-cache git unzip libzip-dev

# Install PHP extensions needed for composer
RUN docker-php-ext-install zip

# Copy only composer files for efficient dependency installation
COPY composer.json composer.lock symfony.lock ./

# Initial install without scripts
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --ignore-platform-reqs \
    --optimize-autoloader

# Copy all files
COPY . .

# Complete installation
RUN composer dump-autoload --optimize --no-dev --classmap-authoritative

# Run post-install scripts with error handling
RUN set -e; \
    if [ -f bin/console ]; then \
        composer run-script post-install-cmd --no-interaction -vvv || \
        (echo "Warning: post-install-cmd failed but continuing build" && exit 0); \
    fi

# Stage 2: Node.js build stage
FROM node:18 as node_builder

WORKDIR /app
COPY --from=builder /app .

# Install npm dependencies and build assets
RUN if [ -f package.json ]; then \
    npm install && \
    npm run build; \
    fi

# Stage 3: Production stage
FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

# Install system dependencies
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
    oniguruma

# Install build dependencies and PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libxml2-dev \
    oniguruma-dev && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    gd \
    pdo_mysql \
    zip \
    mbstring \
    xml \
    intl \
    opcache && \
    apk del .build-deps

# Configure PHP
COPY docker/php/conf.d/opcache.ini /usr/local/etc/php/conf.d/
RUN mkdir -p /usr/local/etc/php-fpm.d && \
    touch /usr/local/etc/php-fpm.d/zz-docker.conf

# Copy built application
COPY --from=builder /app .
COPY --from=node_builder /app/public/build public/build/

# Configure nginx and supervisor
RUN mkdir -p /run/nginx
COPY docker/nginx/nginx.conf /etc/nginx/
COPY docker/nginx/symfony.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/

# Runtime configuration
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

# Set up permissions
RUN chown -R www-data:www-data var public

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s \
    CMD REDIRECT_STATUS=true SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \
    cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1

ENTRYPOINT ["docker-entrypoint"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]