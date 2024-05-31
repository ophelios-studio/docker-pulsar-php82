FROM php:8.2-apache-bookworm

# Install utilities and libraries
RUN apt-get update && apt-get install -y \
    apt-utils gnupg lsb-release ca-certificates wget build-essential cron git curl zip openssl dialog locales \
    libonig-dev libcurl4 libcurl4-openssl-dev supervisor libsqlite3-dev libsqlite3-0 zlib1g-dev libzip-dev libpq-dev libicu-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install xdebug (should be done in project level if needed, because it can cause significant slowdowns)
#RUN pecl install xdebug
#RUN docker-php-ext-enable xdebug

# Install APCu PHP extension
RUN pecl install apcu
RUN docker-php-ext-enable apcu --ini-name docker-php-ext-apcu.ini

# Install Freetype and GD extensions
RUN docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg
RUN docker-php-ext-install gd

# Install PHP extensions
RUN docker-php-ext-install pdo_pgsql && \
    docker-php-ext-install pgsql && \
    docker-php-ext-install curl && \
    docker-php-ext-install zip && \
    docker-php-ext-install intl && \
    docker-php-ext-install xml && \
    docker-php-ext-install mbstring && \
    docker-php-ext-install exif && \
    docker-php-ext-install gettext

# Install Browscap (for browser detection)
RUN mkdir -p /usr/local/etc/php/extra/
RUN curl "http://browscap.org/stream?q=Lite_PHP_BrowsCapINI" -o /usr/local/etc/php/extra/lite_php_browscap.ini

# Install ssh2
RUN apt-get update
RUN apt-get install -y git libssh2-1 libssh2-1-dev
RUN pecl install ssh2-1.3.1
RUN docker-php-ext-enable ssh2

# Enable apache modules
RUN a2enmod rewrite headers expires ssl

# Install SSL certificates (self-signed)
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Install french language locale
RUN localedef -i fr_CA -c -f UTF-8 -A /usr/share/locale/locale.alias fr_CA.UTF-8
ENV LANG fr_CA.UTF-8
ENV LANGUAGE fr_CA.UTF-8
ENV LC_ALL fr_CA.UTF-8

# Crontab
COPY cronjobs /etc/cron.d/cron
RUN chmod 0644 /etc/cron.d/cron && \
    crontab /etc/cron.d/cron && \
    mkdir -p /var/log/cron && \
    sed -i 's/^exec /service cron start\n\nexec /' /usr/local/bin/apache2-foreground

# Install cleanup
RUN rm -rf /usr/src/*

# Timezone
ENV TZ "America/Montreal"

# Duplicity
RUN apt-get -y install duplicity

# Rclone
RUN apt-get -y install rclone

# Mailcatcher
RUN apt-get install -y rubygems ruby-dev sqlite3
RUN gem install mailcatcher --no-document

# Copy specific php.ini directives
COPY custom.ini /usr/local/etc/php/conf.d/base-custom.ini

# Default virtual hosts (https self signed)
COPY vhosts/default.conf /etc/apache2/sites-enabled/default.conf
COPY vhosts/default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf

# Configure and run Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
EXPOSE 80 1080
CMD ["/usr/bin/supervisord"]