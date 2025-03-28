# Stage 1: PHP Composer build stage
FROM composer:2 as builder

WORKDIR /app

# Install system dependencies for composer
RUN apk add --no-cache \
    git \
    unzip \
    libzip-dev

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
        (echo "Warning: post-install-cmd failed but continuing build"; exit 0); \
    fi

# Stage 2: Node.js build stage
FROM node:18-alpine as node_builder

WORKDIR /app
COPY --from=builder /app .

# Install build tools with error handling
RUN set -e; \
    apk add --no-cache --virtual .build-deps \
        python3 \
        make \
        g++; \
    if [ -f package.json ]; then \
        npm config set update-notifier false; \
        npm install --no-audit --progress=false --unsafe-perm || \
        (npm cache clean --force && npm install --no-audit --progress=false --unsafe-perm); \
        if grep -q '"build"' package.json; then \
            npm run build || echo "Build script failed but continuing"; \
        fi; \
    fi; \
    apk del .build-deps; \
    rm -rf /tmp/* /var/cache/apk/* ~/.npm

# Stage 3: Production stage
FROM php:8.2-fpm-alpine

WORKDIR /var/www/html

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
    oniguruma

# Install PHP extensions with robust error handling
RUN set -e; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        libzip-dev \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libxml2-dev \
        oniguruma-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j$(nproc) \
        gd \
        pdo_mysql \
        zip \
        mbstring \
        xml \
        intl \
        opcache; \
    docker-php-source delete; \
    apk del .build-deps; \
    rm -rf /tmp/* /var/cache/apk/*

# Configure PHP
RUN mkdir -p /usr/local/etc/php/conf.d && \
    mkdir -p /usr/local/etc/php-fpm.d
COPY docker/php/conf.d/opcache.ini /usr/local/etc/php/conf.d/

# Fixed PHP-FPM config handling
RUN if [ -f docker/php/php-fpm.d/zz-docker.conf ]; then \
    cp docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/; \
    else \
    echo "Using default PHP-FPM configuration"; \
    touch /usr/local/etc/php-fpm.d/zz-docker.conf; \
    fi

# Copy built application
COPY --from=builder /app .
RUN if [ -d /app/public/build ]; then \
    cp -r /app/public/build public/; \
    else echo "No frontend assets found"; fi

# Configure nginx
RUN mkdir -p /run/nginx && \
    mkdir -p /var/log/nginx && \
    touch /var/log/nginx/access.log /var/log/nginx/error.log
COPY docker/nginx/nginx.conf /etc/nginx/
COPY docker/nginx/symfony.conf /etc/nginx/conf.d/default.conf

# Configure supervisor
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