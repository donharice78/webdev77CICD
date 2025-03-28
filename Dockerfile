# Stage 1: Build stage
FROM composer:2 as builder

WORKDIR /app

# Copy only composer files for efficient dependency installation
COPY composer.json composer.lock symfony.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs

COPY . .
RUN composer dump-autoload --optimize --no-dev --classmap-authoritative
RUN composer run-script post-install-cmd

# Stage 2: Node.js build stage (if you have frontend assets)
FROM node:18 as node_builder

WORKDIR /app
COPY --from=builder /app .

# Install npm dependencies and build assets (adjust as needed)
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
    git \
    nginx \
    supervisor \
    zip \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libxml2-dev \
    oniguruma-dev

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    pdo_mysql \
    zip \
    mbstring \
    xml \
    intl \
    opcache

# Configure PHP
COPY docker/php/conf.d/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/php/php-fpm.d/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf

# Copy built application from builder
COPY --from=builder /app .
COPY --from=node_builder /app/public/build public/build/

# Configure nginx
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/symfony.conf /etc/nginx/conf.d/default.conf

# Configure supervisor
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Runtime configuration
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

# Set up permissions
RUN chown -R www-data:www-data var public

ENTRYPOINT ["docker-entrypoint"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s \
    CMD REDIRECT_STATUS=true SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \
    cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1