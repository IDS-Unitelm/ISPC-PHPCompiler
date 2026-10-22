#!/usr/bin/env bash


#-- Globals

COMPILE_PATH="/usr/local/src/php-build"
CURRENT_PHP_PATH="" # like /opt/php70
CURRENT_PHP_NAME="" # like php70
CURRENT_PHP_VERSION="" # like 70
OUTPUT=""

#-- Helpers Functions

check_return_code() {
        # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
       echo "Error detected in latest command, exiting..."
       rm -r "${COMPILE_PATH:?}/php*" 2&> /dev/null
       exit 1
    fi
}

install_utils() {
    echo -e "Installing required packages..."
    if [ "${DISTRO}" == "centos7" ]; then
        yum -y install epel-release whiptail curl wget ca-certificates
        check_return_code
    elif [ "${DISTRO}" == "centos8" ]; then
        yum -y install epel-release curl wget
        check_return_code
    else
        apt update
        check_return_code
        apt-get -y install whiptail curl wget
        check_return_code
    fi
}

check_folder() {
    if [ ! -d "${1}" ]; then
        echo -e "Creating directory ${1}..."
        mkdir -p "${1}"
        check_return_code
    fi
}

download_extract() {

    ARCHIVE_NAME=${1##*/}
    FOLDER_NAME=${ARCHIVE_NAME/.tar.gz/}

    echo -e "Downloading ${1}..."
    wget --no-check-certificate "${1}" -O "${COMPILE_PATH}/${ARCHIVE_NAME}"
    check_return_code

    if [ "$(sha256sum "${COMPILE_PATH}/${ARCHIVE_NAME}" | cut -d' ' -f1)" != "${2}" ]; then
        echo -e "Checksum mismatch, try to run the script again"
        sha256sum "${COMPILE_PATH}/${ARCHIVE_NAME}"; echo
        exit 126
    else
        echo -e "Checksum matched!"
    fi

        echo -e "Extracting ${ARCHIVE_NAME}..."
    tar zxf "${COMPILE_PATH}/${ARCHIVE_NAME}" -C "${COMPILE_PATH}"
    check_return_code
}

#-- Install Functions

am_i_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit
    fi
}

detect_distro() {
    # shellcheck disable=SC1091
    source /etc/os-release
    check_return_code

    DISTRO=""

    if echo "${ID}-${VERSION_ID}" | grep -iq "devuan-1"; then
        DISTRO=devuan1
    fi

    if echo "${PRETTY_NAME}" | grep -iq "Devuan GNU/Linux ascii"; then
        DISTRO=devuan2
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "debian-3"; then
        DISTRO=devuan3
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "debian-8"; then
        DISTRO=debian8
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "debian-9"; then
        DISTRO=debian9
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "debian-10"; then
        DISTRO=debian10
    fi
    
    if echo "${ID}-${VERSION_ID}" | grep -iq "debian-11"; then
        DISTRO=debian11
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "ubuntu-14.04"; then
        DISTRO=ubuntu-14.04
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "ubuntu-16.04"; then
        DISTRO=ubuntu-16.04
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "ubuntu-17.04"; then
        DISTRO=ubuntu-17.04
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "ubuntu-17.10"; then
        DISTRO=ubuntu-17.10
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "ubuntu-18.04"; then
        DISTRO=ubuntu-18.04
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "ubuntu-20.04"; then
        DISTRO=ubuntu-20.04
    fi
    
    if echo "${ID}-${VERSION_ID}" | grep -iq "ubuntu-22.04"; then
        DISTRO=ubuntu-22.04
    fi
    
    if echo "${ID}-${VERSION_ID}" | grep -iq "centos-7"; then
        DISTRO=centos7
    fi

    if echo "${ID}-${VERSION_ID}" | grep -iq "centos-8"; then
        DISTRO=centos8
    fi

    if [ "${DISTRO}" == "" ]; then
        echo "Your distro is not supported"
        echo "Your distro: ${ID}-${VERSION_ID}"
        echo "You can add it and make a PR ;)"
        exit 127
    fi

}

install_isolated_deps_ubuntu1804() {
    local prefix="/opt/php-deps"
    local cpus
    cpus="$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 2)"
    mkdir -p "${prefix}"

    export PATH="${prefix}/bin:${PATH}"
    export PKG_CONFIG_PATH="${prefix}/lib/pkgconfig:${prefix}/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    export LD_LIBRARY_PATH="${prefix}/lib:${prefix}/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    export LDFLAGS="-L${prefix}/lib -L${prefix}/lib64 ${LDFLAGS}"
    export CPPFLAGS="-I${prefix}/include ${CPPFLAGS}"

    # 1. OpenSSL 1.1.1w
    if [ ! -f "${prefix}/lib/libssl.so" ] && [ ! -f "${prefix}/lib64/libssl.so" ]; then
        echo -e "Compiling isolated OpenSSL 1.1.1w in ${prefix}..."
        rm -f "/tmp/openssl-1.1.1w.tar.gz"
        wget --no-check-certificate "https://www.openssl.org/source/openssl-1.1.1w.tar.gz" -O "/tmp/openssl-1.1.1w.tar.gz"
        check_return_code
        if [ "$(sha256sum "/tmp/openssl-1.1.1w.tar.gz" | cut -d' ' -f1)" != "cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8" ]; then
            echo "OpenSSL checksum mismatch"
            exit 126
        fi
        tar -xzf "/tmp/openssl-1.1.1w.tar.gz" -C /tmp
        check_return_code
        (cd "/tmp/openssl-1.1.1w" && ./config --prefix="${prefix}" --openssldir="${prefix}/ssl" shared zlib && make -j"${cpus}" && make install_sw)
        check_return_code
        rm -rf "/tmp/openssl-1.1.1w" "/tmp/openssl-1.1.1w.tar.gz"
    fi

    # 2. libxml2 2.9.14
    if [ ! -f "${prefix}/lib/libxml2.so" ] && [ ! -f "${prefix}/lib64/libxml2.so" ]; then
        echo -e "Compiling isolated libxml2 2.9.14 in ${prefix}..."
        rm -f "/tmp/libxml2-2.9.14.tar.xz"
        wget --no-check-certificate "https://download.gnome.org/sources/libxml2/2.9/libxml2-2.9.14.tar.xz" -O "/tmp/libxml2-2.9.14.tar.xz"
        check_return_code
        if [ "$(sha256sum "/tmp/libxml2-2.9.14.tar.xz" | cut -d' ' -f1)" != "60d74a257d1ccec0475e749cba2f21559e48139efba6ff28224357c7c798dfee" ]; then
            echo "libxml2 checksum mismatch"
            exit 126
        fi
        tar -xf "/tmp/libxml2-2.9.14.tar.xz" -C /tmp
        check_return_code
        (cd "/tmp/libxml2-2.9.14" && ./configure --prefix="${prefix}" --without-python && make -j"${cpus}" && make install)
        check_return_code
        rm -rf "/tmp/libxml2-2.9.14" "/tmp/libxml2-2.9.14.tar.xz"
    fi

    # 3. libxslt 1.1.39
    if [ ! -f "${prefix}/lib/libxslt.so" ] && [ ! -f "${prefix}/lib64/libxslt.so" ]; then
        echo -e "Compiling isolated libxslt 1.1.39 in ${prefix}..."
        rm -f "/tmp/libxslt-1.1.39.tar.xz"
        wget --no-check-certificate "https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.39.tar.xz" -O "/tmp/libxslt-1.1.39.tar.xz"
        check_return_code
        if [ "$(sha256sum "/tmp/libxslt-1.1.39.tar.xz" | cut -d' ' -f1)" != "2a20ad621148339b0759c4d4e96719362dee64c9a096dbba625ba053846349f0" ]; then
            echo "libxslt checksum mismatch"
            exit 126
        fi
        tar -xf "/tmp/libxslt-1.1.39.tar.xz" -C /tmp
        check_return_code
        (cd "/tmp/libxslt-1.1.39" && ./configure --prefix="${prefix}" --with-libxml-prefix="${prefix}" --without-python && make -j"${cpus}" && make install)
        check_return_code
        rm -rf "/tmp/libxslt-1.1.39" "/tmp/libxslt-1.1.39.tar.xz"
    fi

    # 4. libzip 0.11.2
    if [ ! -f "${prefix}/lib/libzip.so" ] && [ ! -f "${prefix}/lib64/libzip.so" ]; then
        echo -e "Compiling isolated libzip 0.11.2 in ${prefix}..."
        rm -f "/tmp/libzip-0.11.2.tar.gz"
        wget --no-check-certificate "https://libzip.org/download/libzip-0.11.2.tar.gz" -O "/tmp/libzip-0.11.2.tar.gz"
        check_return_code
        if [ "$(sha256sum "/tmp/libzip-0.11.2.tar.gz" | cut -d' ' -f1)" != "83db1fb43a961ff7d1d1b50e1c6bea09c67e6af867686d1fc92ecb7dc6cf98d5" ]; then
            echo "libzip checksum mismatch"
            exit 126
        fi
        tar -xzf "/tmp/libzip-0.11.2.tar.gz" -C /tmp
        check_return_code
        (cd "/tmp/libzip-0.11.2" && ./configure --prefix="${prefix}" && make -j"${cpus}" && make install)
        check_return_code
        rm -rf "/tmp/libzip-0.11.2" "/tmp/libzip-0.11.2.tar.gz"
    fi

    # 5. ICU 69.1 (for intl extension)
    if [ ! -f "${prefix}/lib/libicuuc.so" ] && [ ! -f "${prefix}/lib64/libicuuc.so" ]; then
        echo -e "Compiling isolated ICU 69.1 in ${prefix}..."
        rm -f "/tmp/icu4c-69_1-src.tgz"
        wget --no-check-certificate "https://github.com/unicode-org/icu/releases/download/release-69-1/icu4c-69_1-src.tgz" -O "/tmp/icu4c-69_1-src.tgz"
        check_return_code
        if [ "$(sha256sum "/tmp/icu4c-69_1-src.tgz" | cut -d' ' -f1)" != "4cba7b7acd1d3c42c44bb0c14be6637098c7faf2b330ce876bc5f3b915d09745" ]; then
            echo "ICU checksum mismatch"
            exit 126
        fi
        tar -xzf "/tmp/icu4c-69_1-src.tgz" -C /tmp
        check_return_code
        (cd "/tmp/icu/source" && ./configure --prefix="${prefix}" --disable-samples --disable-tests && make -j"${cpus}" && make install)
        check_return_code
        rm -rf "/tmp/icu" "/tmp/icu4c-69_1-src.tgz"
    fi
}

install_dependencies() {
    if [ "${DISTRO}" == "devuan1" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libjpeg62-turbo-dbg libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libpng12-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libicu-dev libzip-dev pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "devuan2" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "devuan3" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev insserv pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi
    
    if [ "${DISTRO}" == "debian8" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libjpeg62-turbo-dbg libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libpng12-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libicu-dev libzip-dev pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "debian9" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libldb-dev libldap2-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev insserv pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "debian10" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libldb-dev libldap2-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev insserv pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi
    
    if [ "${DISTRO}" == "debian11" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libldb-dev libldap2-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev insserv pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "ubuntu-14.04" ]; then
        apt-get -y install build-essential nano wget libjpeg62-dbg libfcgi-dev libfcgi0ldbl libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libpng12-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libicu-dev libzip-dev libreadline-dev libgmp-dev
        check_return_code
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "ubuntu-16.04" ]; then
        apt-get -y install build-essential nano wget libjpeg62-dbg libfcgi-dev libfcgi0ldbl libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libpng12-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libicu-dev libzip-dev pkg-config zlib1g-dev libsqlite3-dev libonig-dev libreadline-dev libgmp-dev
        check_return_code
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "ubuntu-17.04" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev libreadline-dev libgmp-dev
        check_return_code
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "ubuntu-17.10" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libssl-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev libreadline-dev libgmp-dev
        check_return_code
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi

    if [ "${DISTRO}" == "ubuntu-18.04" ]; then
        # Install base packages that do not conflict with third-party PPAs (like sury.org)
        apt-get -y install build-essential autoconf pkg-config zlib1g-dev libsqlite3-dev libonig-dev libreadline-dev libgmp-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libfreetype6-dev libbz2-dev libkrb5-dev libpq-dev libwebp-dev libvpx-dev libmcrypt-dev libfcgi-dev libfcgi0ldbl
        check_return_code

        # Attempt to install optional packages if available without breaking system
        apt-get -y install libc-client2007e libc-client2007e-dev libldap2-dev libldb-dev 2>/dev/null || true

        # Check if development packages for SSL, XML, Zip, ICU can be installed from APT without conflicts
        # If conflicts are detected (e.g. sury.org PPA installed), build them into /opt/php-deps to protect production services (PHP 7.x)
        if ! apt-get -y install libssl-dev libxml2-dev libxslt1-dev libzip-dev libicu-dev 2>/dev/null; then
            echo "Third-party repository conflicts detected (e.g. sury.org). Installing isolated build dependencies in /opt/php-deps to protect running PHP services..."
            install_isolated_deps_ubuntu1804
        fi

        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl 2>/dev/null || true
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a 2>/dev/null || true
    fi
    
    if [ "${DISTRO}" == "ubuntu-20.04" ]; then
        # First install dependencies without libxml2-dev to avoid conflicts
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libssl-dev libldb-dev libldap2-dev libc-client2007e libc-client2007e-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        
        # Install libxml2-dev and libxslt1-dev separately, handling version conflicts
        # This allows apt to resolve dependencies with already installed libxml2 versions (e.g., from sury.org)
        apt-get -y install libxml2-dev libxslt1-dev || {
            echo "Trying alternative method for libxml2-dev installation..."
            # If standard install fails, try with --allow-change-held-packages
            apt-get -y --allow-change-held-packages install libxml2-dev libxslt1-dev || {
                echo "Installing matching libxml2-dev version for current libxml2..."
                # Install the -dev package that matches the currently installed libxml2 version
                LIBXML2_VERSION=$(dpkg -s libxml2 2>/dev/null | grep '^Version:' | awk '{print $2}')
                if [ -n "${LIBXML2_VERSION}" ]; then
                    apt-get -y install libxml2-dev="${LIBXML2_VERSION}" libxslt1-dev || true
                fi
            }
        }
        
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl 2>/dev/null || true
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a 2>/dev/null || true
    fi
    
    if [ "${DISTRO}" == "ubuntu-22.04" ]; then
        apt-get -y install build-essential autoconf libfcgi-dev libfcgi0ldbl libmcrypt-dev libssl-dev libldb-dev libldap2-dev libc-client2007e libc-client2007e-dev libxml2-dev libbz2-dev libcurl4-openssl-dev libjpeg-dev libfreetype6-dev libkrb5-dev libpq-dev libxml2-dev libxslt1-dev libwebp-dev libvpx-dev libc-client2007e-dev libicu-dev libzip-dev pkg-config zlib1g-dev libsqlite3-dev libonig-dev icu-devtools libreadline-dev libgmp-dev
        check_return_code
        ln -s  /usr/include/x86_64-linux-gnu/curl  /usr/include/curl
        ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
    fi
    
    if [ "${DISTRO}" == "centos7" ]; then
        yum -y --nogpgcheck install gcc make libc-client-devel libxml2-devel pkgconfig openssl-devel bzip2-devel libldb-devel curl-devel libpng-devel libpng-devel libjpeg-devel libXpm-devel freetype-devel gmp-devel libmcrypt-devel mariadb-devel aspell-devel recode-devel httpd-devel postgresql-devel libxslt-devel libwebp-devel libvpx-devel libicu-devel gcc-c++ pkg-config zlib-devel libsqlite3x-devel oniguruma-devel readline-devel
        check_return_code

        wget https://libzip.org/download/libzip-0.11.2.tar.gz -O /tmp/libzip-0.11.2.tar.gz
        check_return_code
        if [ "$(sha256sum /tmp/libzip-0.11.2.tar.gz | cut -d' ' -f1)" != "83db1fb43a961ff7d1d1b50e1c6bea09c67e6af867686d1fc92ecb7dc6cf98d5" ]; then
            echo "libzip 0.11.2 checksum mismatch"
            exit 126
        fi
        tar -xzf /tmp/libzip-0.11.2.tar.gz -C /tmp
        check_return_code
        (cd /tmp/libzip-0.11.2 && ./configure --prefix=/usr/local && make -j"$(grep -c ^processor /proc/cpuinfo)" && make install)
        check_return_code
        ldconfig
        check_return_code
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
        rm -rf /tmp/libzip-0.11.2 /tmp/libzip-0.11.2.tar.gz
    fi
    
    if [ "${DISTRO}" == "centos8" ]; then
        dnf -y install gcc make libc-client-devel libxml2-devel pkgconfig openssl-devel bzip2-devel curl-devel libpng-devel libpng-devel libjpeg-devel libXpm-devel freetype-devel gmp-devel libmcrypt-devel mariadb-devel httpd-devel postgresql-devel libxslt-devel libwebp-devel libicu-devel gcc-c++ libzip-devel pkg-config zlib-devel libsqlite3x-devel readline-devel
        check_return_code
        dnf -y --enablerepo=powertools install oniguruma-devel
        check_return_code
    fi
}

show_menu() {
    menu=()

    readarray -t _sorted < <(printf '%s\n' "${!VERSIONS[@]}" | sort)

    for version in "${_sorted[@]}"; do
        menu+=( "${version}" "" )
    done

    USER_SELECTION=$(whiptail --title "PHP Compiler" --menu "Install or update:" $((${#menu[@]}+10)) 30 ${#menu[@]} "${menu[@]}" 3>&1 1>&2 2>&3)
}

# $1=php_name (like 'php70'), $2=php_path (like '/opt/php70')
create_init_script() {

cat << "EOF" > "/etc/init.d/${1}-fpm"
#! /bin/sh
### BEGIN INIT INFO
# Provides:          &NAME&-fpm
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts &NAME&-fpm
# Description:       starts the PHP FastCGI Process Manager daemon
### END INIT INFO
php_fpm_BIN=&PATH&/sbin/php-fpm
php_fpm_CONF=&PATH&/etc/php-fpm.conf
php_fpm_PID=&PATH&/var/run/php-fpm.pid
php_opts="--fpm-config $php_fpm_CONF"
wait_for_pid () {
        try=0
        while test $try -lt 35 ; do
                case "$1" in
                        'created')
                        if [ -f "$2" ] ; then
                                try=''
                                break
                        fi
                        ;;
                        'removed')
                        if [ ! -f "$2" ] ; then
                                try=''
                                break
                        fi
                        ;;
                esac
                echo -n .
                try=`expr $try + 1`
                sleep 1
        done
}
case "$1" in
        start)
                echo -n "Starting php-fpm "
                $php_fpm_BIN $php_opts
                if [ "$?" != 0 ] ; then
                        echo " failed"
                        exit 1
                fi
                wait_for_pid created $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed"
                        exit 1
                else
                        echo " done"
                fi
        ;;
        stop)
                echo -n "Gracefully shutting down php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -QUIT `cat $php_fpm_PID`
                wait_for_pid removed $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed. Use force-exit"
                        exit 1
                else
                        echo " done"
                       echo " done"
                fi
        ;;
        force-quit)
                echo -n "Terminating php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -TERM `cat $php_fpm_PID`
                wait_for_pid removed $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed"
                        exit 1
                else
                        echo " done"
                fi
        ;;
        restart)
                $0 stop
                $0 start
        ;;
        reload)
                echo -n "Reload service php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -USR2 `cat $php_fpm_PID`
                echo " done"
        ;;
        *)
                echo "Usage: $0 {{start|stop|force-quit|restart|reload}}"
                exit 1
        ;;
esac
EOF

sed -i "s:&NAME&:${1}:g" "/etc/init.d/${1}-fpm"
sed -i "s:&PATH&:${2}:g" "/etc/init.d/${1}-fpm"

}

# $1=php_name (like 'php70'), $2=php_path (like '/opt/php70')
create_systemd_script() {

cat << "EOF" > "/lib/systemd/system/${1}-fpm.service"
[Unit]
Description=The &NAME& FastCGI Process Manager
After=network.target

[Service]
Type=simple
PIDFile=&PATH&/var/run/php-fpm.pid
ExecStart=&PATH&/sbin/php-fpm --nodaemonize --fpm-config &PATH&/etc/php-fpm.conf
ExecReload=/bin/kill -USR2 $MAINPID

[Install]
WantedBy=multi-user.target
EOF

sed -i "s:&NAME&:${1}:g" "/lib/systemd/system/${1}-fpm.service"
sed -i "s:&PATH&:${2}:g" "/lib/systemd/system/${1}-fpm.service"
}

compile_openssl() {
    #version="1.1.1q"
    
    #wget "https://www.openssl.org/source/openssl-${version}.tar.gz" -O "/tmp/openssl.tar.gz"
    #check_return_code

    wget "http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb" -O "/tmp/openssl.deb"
    check_return_code
    
    dpkg -i /tmp/openssl.deb
    check_return_code

    #tar -xzf "/tmp/openssl.tar.gz" -C "/tmp/"
    #check_return_code

    #(cd "/tmp/openssl-${version}/" && ./Configure --prefix=/tmp/openssl/bin -fPIC -shared linux-x86_64)
    #check_return_code

    #(cd "/tmp/openssl-${version}/" && make -j 8 )
    #check_return_code

    #(cd "/tmp/openssl-${version}/" && make install)
    #check_return_code
}

compile_openssl_centos7() {
    local version="1.1.1w"
    local prefix="/usr/local/openssl-${version}"

    if [ -x "${prefix}/bin/openssl" ]; then
        return
    fi

    wget "https://www.openssl.org/source/openssl-${version}.tar.gz" -O "/tmp/openssl-${version}.tar.gz"
    check_return_code
    if [ "$(sha256sum "/tmp/openssl-${version}.tar.gz" | cut -d' ' -f1)" != "cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8" ]; then
        echo "OpenSSL ${version} checksum mismatch"
        exit 126
    fi

    tar -xzf "/tmp/openssl-${version}.tar.gz" -C /tmp
    check_return_code
    (cd "/tmp/openssl-${version}" && ./config --prefix="${prefix}" --openssldir="${prefix}/ssl" shared zlib && make -j"$(grep -c ^processor /proc/cpuinfo)" && make install_sw)
    check_return_code
    echo "${prefix}/lib" > /etc/ld.so.conf.d/openssl-1.1.1w.conf
    ldconfig
    check_return_code
    rm -rf "/tmp/openssl-${version}" "/tmp/openssl-${version}.tar.gz"
}

compile_freetype() {
    version="2.10.1"

    wget "https://downloads.sourceforge.net/freetype/freetype-${version}.tar.xz" -O "/tmp/freetype.tar.xz"
    check_return_code

    tar -xf "/tmp/freetype.tar.xz" -C "/tmp/"
    check_return_code

    (cd "/tmp/freetype-${version}/" && sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg)
    check_return_code

    (cd "/tmp/freetype-${version}/" && sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h)
    check_return_code

    (cd "/tmp/freetype-${version}/" && ./configure --prefix=/tmp/freetype2/ --enable-freetype-config --disable-static)
    check_return_code

    make -C "/tmp/freetype-${version}/" -j"${CPU_COUNT}"
    check_return_code

    make -C "/tmp/freetype-${version}/" install
    check_return_code
}

compile() {
    ADDITIONAL_CFLAGS="-march=native -mtune=native"
    libdir="--with-libdir=/lib/x86_64-linux-gnu"
    webp="--with-webp-dir=/usr"
    zip="--enable-zip --with-libzip"
    freetype="--with-freetype-dir"
    gd="--with-gd"
    jpg="--with-jpeg-dir=/usr"
    openssl="--with-openssl"
    ldap="--with-ldap"
    libxml="--with-libxml-dir=/usr"
    xmlrpc="--with-xmlrpc"
    imap="--with-imap --with-imap-ssl --with-kerberos"

    if [ "${DISTRO}" == "ubuntu-18.04" ] || [ -d "/opt/php-deps" ] || { [ ! -f "/usr/include/c-client/utf8.h" ] && [ ! -f "/usr/include/imap/utf8.h" ] && [ ! -f "/usr/include/utf8.h" ]; }; then
        echo "Skipping IMAP extension (c-client headers unavailable or conflict with OpenSSL)."
        imap=""
    fi

    if [ "${CURRENT_PHP_VERSION}" -ge 80 ]; then
        xmlrpc=""
    fi

    if [ -d "/opt/php-deps" ]; then
        export PKG_CONFIG_PATH="/opt/php-deps/lib/pkgconfig:/opt/php-deps/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
        export LDFLAGS="-Wl,-rpath,/opt/php-deps/lib:/opt/php-deps/lib64 -L/opt/php-deps/lib -L/opt/php-deps/lib64 ${LDFLAGS}"
        export CPPFLAGS="-I/opt/php-deps/include ${CPPFLAGS}"
        openssl="--with-openssl=/opt/php-deps"
        libxml="--with-libxml-dir=/opt/php-deps"
    fi
    if [ "${DISTRO}" == "centos7" ] || [ "${DISTRO}" == "centos8" ]; then
        libdir="--with-libdir=lib64"
        zip="--enable-zip"

        if [ "${CURRENT_PHP_VERSION}" -gt 72 ]; then
                ADDITIONAL_CFLAGS=""
        fi
    fi

    if [ "${DISTRO}" == "ubuntu-14.04" ]; then
        zip="--enable-zip"

        if [ "${CURRENT_PHP_VERSION}" -eq 73 ]; then
            zip="--enable-zip --without-libzip"
            ADDITIONAL_CFLAGS=""
        fi
    fi

    if [ "${CURRENT_PHP_VERSION}" -lt 70 ]; then
        webp="--with-vpx-dir=/usr"
    fi

    gmp="--with-gmp"
    if [ "${DISTRO}" == "ubuntu-16.04" ] && [ "${CURRENT_PHP_VERSION}" -lt 70 ]; then
        gmp=""
    fi

    if { [ "${DISTRO}" == "debian11" ] || [ "${DISTRO}" == "debian10" ] || [ "${DISTRO}" == "devuan3" ] || [ "${DISTRO}" == "ubuntu-20.04" ] || [ "${DISTRO}" == "ubuntu-22.04" ]; } && [ "${CURRENT_PHP_VERSION}" -lt 74 ]; then
        compile_freetype
        freetype="--with-freetype-dir=/tmp/freetype2"
    fi
	
    if [ "${DISTRO}" == "ubuntu-22.04" ]; then
        compile_openssl
        #openssl="--with-openssl --with-openssl-dir=/tmp/openssl"
	openssl="--with-openssl PKG_CONFIG_PATH=/tmp/openssl/bin/lib/pkgconfig"
    fi

    if [ "${DISTRO}" == "centos7" ] && [ "${CURRENT_PHP_VERSION}" -ge 80 ]; then
        compile_openssl_centos7
        openssl="--with-openssl=/usr/local/openssl-1.1.1w"
        export PKG_CONFIG_PATH="/usr/local/openssl-1.1.1w/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    fi

    if [ "${CURRENT_PHP_VERSION}" -gt 73 ]; then
        gd="--enable-gd"
        freetype="--with-freetype"
        jpg="--with-jpeg"
        webp="--with-webp"
        zip="--with-zip"
        libxml=""
    fi

    # shellcheck disable=SC2086
    (cd "${COMPILE_PATH}/${FOLDER_NAME}" && ./configure CFLAGS="-O3 ${ADDITIONAL_CFLAGS}" \
        --prefix=${CURRENT_PHP_PATH} --with-pdo-pgsql --with-zlib-dir ${freetype} --enable-mbstring \
        ${libxml} --enable-soap --enable-calendar --with-curl --with-mcrypt \
        --with-zlib ${gd} --with-pgsql --disable-rpath --enable-inline-optimization \
        --with-bz2 --with-zlib --enable-sockets --enable-sysvsem --enable-sysvshm \
        --enable-pcntl --enable-mbregex --enable-exif --enable-bcmath --with-mhash \
        ${zip} --with-pcre-regex --with-pdo-mysql --with-mysqli --with-mysql-sock=/var/run/mysqld/mysqld.sock \
        ${jpg} --with-png-dir=/usr ${openssl} --with-fpm-user=www-data \
        --with-fpm-group=www-data ${libdir} --enable-ftp ${imap} ${ldap} \
        --with-gettext ${xmlrpc} ${webp} --with-xsl \
        --enable-opcache --enable-intl --enable-fpm --with-pear --with-readline ${gmp})
    check_return_code

    CPU_COUNT=$(grep -c ^processor /proc/cpuinfo)

    make -C "${COMPILE_PATH}/${FOLDER_NAME}" -j"${CPU_COUNT}"
    check_return_code

    if [ -d "${CURRENT_PHP_PATH}" ]; then
        echo -e "Stopping services..."
        systemctl stop "${CURRENT_PHP_NAME}-fpm.service"
    fi

    make -C "${COMPILE_PATH}/${FOLDER_NAME}" install
    check_return_code
}

install() {
    # shellcheck disable=SC2086
    if [ -f /.dockerenv ]; then
        FPM_PORT=$(shuf -i 2000-50000 -n 1)
        if [ "${DISTRO}" == "centos7" ]; then
            useradd -M www-data
        fi
    else
        while :; do
            FPM_PORT=$(whiptail --title "PHP Compiler" --nocancel --inputbox "Choose the FPM port for ${CURRENT_PHP_NAME}" 10 40 ""  3>&1 1>&2 2>&3)
            if [ "$(netstat -tunl | grep -P "^(?=.*LISTEN)(?=.*${FPM_PORT})" -c)" -eq 0 ]; then
                break
            fi
        done
    fi

    cp "${COMPILE_PATH}/${FOLDER_NAME}/php.ini-production" "${CURRENT_PHP_PATH}/lib/php.ini"
    cp "${CURRENT_PHP_PATH}/etc/php-fpm.conf.default" "${CURRENT_PHP_PATH}/etc/php-fpm.conf"

    sed -i 's/;pid = run\/php-fpm.pid/pid = run\/php-fpm.pid/' "${CURRENT_PHP_PATH}/etc/php-fpm.conf"

    if [ "${CURRENT_PHP_VERSION}" -lt 70 ]; then
        sed -i "s/listen = 127.0.0.1:9000/listen = 127.0.0.1:${FPM_PORT}/" "${CURRENT_PHP_PATH}/etc/php-fpm.conf"
        echo "include=${CURRENT_PHP_PATH}/etc/php-fpm.d/*.conf" >> "${CURRENT_PHP_PATH}/etc/php-fpm.conf"
        check_folder "${CURRENT_PHP_PATH}/etc/php-fpm.d"
    else
        cp "${CURRENT_PHP_PATH}/etc/php-fpm.d/www.conf.default" "${CURRENT_PHP_PATH}/etc/php-fpm.d/www.conf"
        sed -i "s/listen = 127.0.0.1:9000/listen = 127.0.0.1:${FPM_PORT}/" "${CURRENT_PHP_PATH}/etc/php-fpm.d/www.conf"
    fi

    create_init_script "${CURRENT_PHP_NAME}" "${CURRENT_PHP_PATH}"
    chmod 755 "/etc/init.d/${CURRENT_PHP_NAME}-fpm"
    insserv "${CURRENT_PHP_NAME}-fpm"

    create_systemd_script "${CURRENT_PHP_NAME}" "${CURRENT_PHP_PATH}"

    systemctl enable "${CURRENT_PHP_NAME}-fpm.service"
    systemctl daemon-reload

    echo "zend_extension=opcache.so" >> "${CURRENT_PHP_PATH}/lib/php.ini"

    systemctl start "${CURRENT_PHP_NAME}-fpm.service"
}

check_symlink() {
        if [ ! -f "/usr/bin/${CURRENT_PHP_NAME}" ]; then
                ln -s "${CURRENT_PHP_PATH}/bin/php" "/usr/bin/${CURRENT_PHP_NAME}"
                update-alternatives --install /usr/bin/php php "/opt/${CURRENT_PHP_NAME}/bin/php" "${CURRENT_PHP_VERSION}"
        fi
}

completed() {
    OUTPUT="${OUTPUT}----------- COMPLETED: [${CURRENT_PHP_NAME}] -----------\\n"
    OUTPUT="${OUTPUT}FastCGI Settings:\\n"
    OUTPUT="${OUTPUT} - Path to the PHP FastCGI binary: ${CURRENT_PHP_PATH}/bin/php-cgi\\n"
    OUTPUT="${OUTPUT} - Path to the php.ini directory: ${CURRENT_PHP_PATH}/lib\\n"
    OUTPUT="${OUTPUT}PHP-FPM Settings:\\n"
    OUTPUT="${OUTPUT} - Path to the PHP-FPM init script: /etc/init.d/${CURRENT_PHP_NAME}-fpm\\n"
    OUTPUT="${OUTPUT} - Path to the php.ini directory: ${CURRENT_PHP_PATH}/lib\\n"
    OUTPUT="${OUTPUT} - Path to the PHP-FPM pool directory: ${CURRENT_PHP_PATH}/etc/php-fpm.d\\n"
    OUTPUT="${OUTPUT}------------------------------------------\\n"
}

cleanup() {
    rm -r "${COMPILE_PATH:?}/${FOLDER_NAME}"
    rm -r "${COMPILE_PATH:?}/${ARCHIVE_NAME}"

    if { [ "${DISTRO}" == "debian11" ] ||[ "${DISTRO}" == "debian10" ] || [ "${DISTRO}" == "devuan3" ] || [ "${DISTRO}" == "ubuntu-20.04" ] || [ "${DISTRO}" == "ubuntu-22.04" ]; } && [ "${CURRENT_PHP_VERSION}" -lt 74 ]; then
        rm -r /tmp/freetype-*/
        rm -r "/tmp/freetype.tar.xz"
        rm -r "/tmp/freetype2/"
    fi
	
	if [ "${DISTRO}" == "ubuntu-22.04" ]; then
        rm -r /tmp/openssl-*/
    fi
}

elaborate_selection() {

        if [ "${USER_SELECTION}" == "" ]; then
                echo -e "Installation aborted."
                exit
        fi

    escaped_selection="${USER_SELECTION//\"/}"
    CURRENT_PHP_NAME="php${escaped_selection:4:1}${escaped_selection:6:1}"
    CURRENT_PHP_PATH="/opt/${CURRENT_PHP_NAME}"
    CURRENT_PHP_VERSION="${escaped_selection:4:1}${escaped_selection:6:1}"

    if { [ "${DISTRO}" == "centos8" ] || [ "${DISTRO}" == "debian9" ] || [ "${DISTRO}" == "debian10" ] || [ "${DISTRO}" == "debian11" ] || [ "${DISTRO}" == "devuan2" ] || [ "${DISTRO}" == "devuan3" ] || [ "${DISTRO}" == "ubuntu-18.04" ] || [ "${DISTRO}" == "ubuntu-20.04" ] || [ "${DISTRO}" == "ubuntu-22.04" ]; } && [ "${CURRENT_PHP_NAME}" == "php56" ]; then
        echo -e "Your current distro(${DISTRO}) not support this php version building (${CURRENT_PHP_NAME}). Sorry..."
        exit 5
    fi

    if { [ "${DISTRO}" == "debian11" ] || [ "${DISTRO}" == "debian10" ] || [ "${DISTRO}" == "devuan3" ] || [ "${DISTRO}" == "ubuntu-20.04" ]  || [ "${DISTRO}" == "ubuntu-22.04" ]; } && [ "${CURRENT_PHP_NAME}" == "php70" ]; then
        echo -e "Your current distro(${DISTRO}) not support this php version building (${CURRENT_PHP_NAME}). Sorry..."
        exit 5
    fi       

    echo -e "Checking compile path..."
    check_folder "${COMPILE_PATH}"

    download_extract "${VERSIONS[$USER_SELECTION]}" "${CHECKSUM[$USER_SELECTION]}"

    echo -e "Compiling..."
    if [ ! -d "${CURRENT_PHP_PATH}" ]; then
        compile
        echo -e "First time setup..."
        install
    else
        compile
        echo -e "Restarting services..."
        systemctl restart "${CURRENT_PHP_NAME}-fpm.service"
    fi
    check_symlink
    completed
    cleanup
    echo -e "${OUTPUT}"
}

am_i_root
detect_distro
install_utils "$@"
install_dependencies

if [ -f ./versions.sh ]; then
    echo "Using local versions.sh"
    # shellcheck source=./versions.sh
    source ./versions.sh
else
    # shellcheck disable=SC1090
    source <(curl -s https://raw.githubusercontent.com/IDS-Unitelm/ISPC-PHPCompiler/bash-version/versions.sh)
fi

check_return_code

if [ -f /.dockerenv ]; then
    USER_SELECTION="${1}"
else
    show_menu
fi

elaborate_selection
