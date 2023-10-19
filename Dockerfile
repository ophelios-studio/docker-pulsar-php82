FROM php:8.2-apache-bookworm

# Install utilities and libraries
RUN apt-get update && apt-get install -y \
    apt-utils gnupg lsb-release ca-certificates wget build-essential cron git curl zip openssl dialog locales \
    libonig-dev libcurl4 libcurl4-openssl-dev libsqlite3-dev libsqlite3-0 zlib1g-dev libzip-dev libpq-dev libicu-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Docker cli
RUN mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get install -y docker-ce-cli

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install xdebug
RUN pecl install xdebug
RUN docker-php-ext-enable xdebug

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
RUN a2enmod rewrite headers expires

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

# Prepare sudo for Docker command
RUN apt-get install sudo -y
RUN adduser --disabled-password \
--gecos '' docker
RUN adduser docker sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> \
/etc/sudoers
USER docker

# Copy specific php.ini directives
COPY custom.ini /usr/local/etc/php/conf.d/base-custom.ini
