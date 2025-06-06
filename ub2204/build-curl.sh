#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS
_ORIG_LDFLAGS="${LDFLAGS}"

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

_private_dir='usr/lib/x86_64-linux-gnu/curl/private'

set -e

_strip_files() {
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
}

_install_go() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    # Latest version of go
    #_go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"

    # go1.24.X
    _go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | grep '^1\.24\.' | tail -n 1)"

    wget -q -c -t 0 -T 9 "https://dl.google.com/go/go${_go_version}.linux-amd64.tar.gz"
    rm -fr /usr/local/go
    sleep 1
    install -m 0755 -d /usr/local/go
    tar -xof "go${_go_version}.linux-amd64.tar.gz" --strip-components=1 -C /usr/local/go/
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
}

_build_zlib() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --64
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.so*
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.a
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_gmp() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #wget 'https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz'
    _gmp_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/gmp/' | grep -i 'gmp-[0-9]' | sed -e 's|"|\n|g' | grep -i '^gmp-[0-9].*xz$' | sed -e 's|gmp-||g' -e 's|\.tar.*||g' | sort -V | tail -n1)"
    wget -c -t 9 -T 9 "https://ftp.gnu.org/gnu/gmp/gmp-${_gmp_ver}.tar.xz"
    tar -xof gmp-*.tar*
    sleep 1
    rm -f gmp-*.tar*
    cd gmp-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-cxx --enable-fat \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed -e 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' \
    -e 's|^runpath_var=LD_RUN_PATH|runpath_var=DIE_RPATH_DIE|g' \
    -e 's|-lstdc++ -lm|-lstdc++|' \
    -i libtool
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/gmp
    make install DESTDIR=/tmp/gmp
    install -v -m 0644 gmp-mparam.h /tmp/gmp/usr/include/
    cd /tmp/gmp
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/gmp
    /sbin/ldconfig
}

_build_cares() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _cares_ver="$(wget -qO- 'https://c-ares.org/' | grep -i '/download/.*/c-ares-[1-9].*\.tar' | sed -e 's|"|\n|g' | grep -i '/download.*tar.gz$' | sed -e 's|.*c-ares-||g' -e 's|\.tar.*||g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/c-ares/c-ares/releases/download/v${_cares_ver}/c-ares-${_cares_ver}.tar.gz"
    tar -xof c-ares-*.tar*
    sleep 1
    rm -f c-ares-*.tar*
    cd c-ares-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/cares
    make install DESTDIR=/tmp/cares
    cd /tmp/cares
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/cares
    /sbin/ldconfig
}

_build_brotli() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/google/brotli.git' brotli
    cd brotli
    rm -fr .git
    if [[ -f bootstrap ]]; then
        ./bootstrap
        rm -fr autom4te.cache
        LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
        ./configure \
        --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
        --enable-shared --disable-static \
        --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
        make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
        rm -fr /tmp/brotli
        make install DESTDIR=/tmp/brotli
    else
        LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$ORIGIN' ; export LDFLAGS
        cmake \
        -S "." \
        -B "build" \
        -DCMAKE_BUILD_TYPE='Release' \
        -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
        -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
        -DSYSCONF_INSTALL_DIR:PATH=/etc \
        -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
        -DLIB_SUFFIX=64 \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
        cmake --build "build"  --verbose
        rm -fr /tmp/brotli
        DESTDIR="/tmp/brotli" cmake --install "build"
    fi
    cd /tmp/brotli
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}

_build_lz4() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive "https://github.com/lz4/lz4.git"
    cd lz4
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu
    rm -fr /tmp/lz4
    make install DESTDIR=/tmp/lz4
    cd /tmp/lz4
    _strip_files
    find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/lz4
    /sbin/ldconfig
}

_build_zstd() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive "https://github.com/facebook/zstd.git"
    cd zstd
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$OOORIGIN' ; export LDFLAGS
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu
    rm -fr /tmp/zstd
    make install DESTDIR=/tmp/zstd
    cd /tmp/zstd
    _strip_files
    find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zstd
    /sbin/ldconfig
}

_build_libunistring() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libunistring_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/libunistring/' | grep -i 'libunistring-[0-9]' | sed -e 's|"|\n|g' | grep -i '^libunistring-[0-9].*xz$' | sed -e 's|libunistring-||g' -e 's|\.tar.*||g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://ftp.gnu.org/gnu/libunistring/libunistring-${_libunistring_ver}.tar.xz"
    tar -xof libunistring-*.tar*
    sleep 1
    rm -f libunistring-*.tar*
    cd libunistring-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-largefile --enable-year2038 \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/libunistring
    make install DESTDIR=/tmp/libunistring
    cd /tmp/libunistring
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libunistring
    /sbin/ldconfig
}

_build_libexpat() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _expat_ver="$(wget -qO- 'https://github.com/libexpat/libexpat/releases' | grep -i '/libexpat/libexpat/tree/' | sed 's|"|\n|g' | grep -i '^/libexpat/libexpat/tree/' | sed 's|.*R_||g' | sed 's|_|.|g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/libexpat/libexpat/releases/download/R_${_expat_ver//./_}/expat-${_expat_ver}.tar.bz2"
    tar -xof expat-*.tar*
    sleep 1
    rm -f expat-*.tar*
    cd expat-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/libexpat
    make install DESTDIR=/tmp/libexpat
    cd /tmp/libexpat
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libexpat
    /sbin/ldconfig
}

_build_openssl33() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #_openssl33_ver="$(wget -qO- 'https://www.openssl.org/source/' | grep 'openssl-3\.3\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.3\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    #wget -c -t 9 -T 9 "https://www.openssl.org/source/openssl-${_openssl33_ver}.tar.gz"
    _openssl33_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.3\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.3\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://github.com/openssl/openssl/releases/download/openssl-${_openssl33_ver}/openssl-${_openssl33_ver}.tar.gz
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/openssl33
    make DESTDIR=/tmp/openssl33 install_sw
    cd /tmp/openssl33
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl33
    /sbin/ldconfig
}

_build_openssl34() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl34_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.4\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.4\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/openssl/openssl/releases/download/openssl-${_openssl34_ver}/openssl-${_openssl34_ver}.tar.gz"
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc) all
    rm -fr /tmp/openssl34
    make DESTDIR=/tmp/openssl34 install_sw
    cd /tmp/openssl34
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl34
    /sbin/ldconfig
}

_build_openssl35() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl35_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.5\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.5\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://github.com/openssl/openssl/releases/download/openssl-${_openssl35_ver}/openssl-${_openssl35_ver}.tar.gz
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS=''; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc --all) all
    rm -fr /tmp/openssl35
    make DESTDIR=/tmp/openssl35 install_sw
    cd /tmp/openssl35
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl35
    /sbin/ldconfig
}

_build_aws-lc() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _aws_lc_tag="$(wget -qO- 'https://github.com/aws/aws-lc/tags' | grep -i 'href="/.*/releases/tag/' | sed 's|"|\n|g' | grep -i '/releases/tag/' | sed 's|.*/tag/||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/aws/aws-lc/archive/refs/tags/${_aws_lc_tag}.tar.gz"
    tar -xof *.tar*
    sleep 1
    rm -f *.tar*
    cd aws*
    # Go programming language
    export GOROOT='/usr/local/go'
    export GOPATH="$GOROOT/home"
    export GOTMPDIR='/tmp'
    export GOBIN="$GOROOT/bin"
    export PATH="$GOROOT/bin:$PATH"
    alias go="$GOROOT/bin/go"
    alias gofmt="$GOROOT/bin/gofmt"
    rm -fr ~/.cache/go-build
    echo
    go version
    echo
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$ORIGIN'; export LDFLAGS
    cmake \
    -GNinja \
    -S "." \
    -B "aws-lc-build" \
    -DCMAKE_BUILD_TYPE='Release' \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr \
    -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
    -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
    -DSYSCONF_INSTALL_DIR:PATH=/etc \
    -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
    -DLIB_SUFFIX=64 \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
    cmake --build "aws-lc-build" --parallel $(nproc --all) --verbose
    rm -fr /tmp/aws-lc
    DESTDIR="/tmp/aws-lc" cmake --install "aws-lc-build"
    cd /tmp/aws-lc
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -vf usr/bin/openssl
    rm -vf usr/bin/c_rehash
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -vf /usr/lib/x86_64-linux-gnu/libssl.so
    rm -vf /usr/lib/x86_64-linux-gnu/libcrypto.so
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/aws-lc
    /sbin/ldconfig
}

_build_libssh2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libssh2_ver="$(wget -qO- 'https://www.libssh2.org/' | grep 'libssh2-[1-9].*\.tar\.' | sed 's|"|\n|g' | grep -i '^download/libssh2-[1-9]' | sed -e 's|.*libssh2-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc[0-9]' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.libssh2.org/download/libssh2-${_libssh2_ver}.tar.gz"
    tar -xof libssh2-*.tar*
    sleep 1
    rm -f libssh2-*.tar*
    cd libssh2-*

    if [[ "${_libssh2_ver}" == '1.11.0' ]]; then
        echo 'diff --git a/configure.ac b/configure.ac
        index a4d386b..6b79684 100644
        --- a/configure.ac
        +++ b/configure.ac
        @@ -387,6 +387,8 @@ elif test "$found_crypto" = "mbedtls"; then
           LIBS="${LIBS} ${LTLIBMBEDCRYPTO}"
         fi
 
        +LIBS="${LIBS} ${LTLIBZ}"
        +
         AC_CONFIG_FILES([Makefile
                          src/Makefile
                          tests/Makefile
        diff --git a/src/Makefile.am b/src/Makefile.am
        index 91222d5..380674b 100644
        --- a/src/Makefile.am
        +++ b/src/Makefile.am
        @@ -48,8 +48,7 @@ VERSION=-version-info 1:1:0
         #
 
         libssh2_la_LDFLAGS = $(VERSION) -no-undefined \
        -  -export-symbols-regex '\''^libssh2_.*'\'' \
        -  $(LTLIBZ)
        +  -export-symbols-regex '\''^libssh2_.*'\''
 
         if HAVE_WINDRES
         .rc.lo:' > ../fix-build-with-openssl111.patch
        sed 's|^        ||g' -i ../fix-build-with-openssl111.patch
        patch -N -p1 -i ../fix-build-with-openssl111.patch
        autoreconf -ifv
        rm -fr autom4te.cache
        rm -f configure.ac.orig src/Makefile.am.orig
    fi

    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --disable-silent-rules --with-libz --enable-debug --with-crypto=openssl \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/libssh2
    make install DESTDIR=/tmp/libssh2
    cd /tmp/libssh2
    _strip_files
    sed -e '/^Libs/s/-R[^ ]*//g' -e '/^Libs/s/ *$//' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libssh2
    /sbin/ldconfig
}

_build_pcre2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _pcre2_ver="$(wget -qO- 'https://github.com/PCRE2Project/pcre2/releases' | grep -i 'pcre2-[1-9]' | sed 's|"|\n|g' | grep -i '^/PCRE2Project/pcre2/tree' | sed 's|.*/pcre2-||g' | sed 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${_pcre2_ver}/pcre2-${_pcre2_ver}.tar.bz2"
    tar -xof pcre2-${_pcre2_ver}.tar.*
    sleep 1
    rm -f pcre2-*.tar*
    cd pcre2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 \
    --enable-jit \
    --enable-pcre2grep-libz --enable-pcre2grep-libbz2 \
    --enable-pcre2test-libedit --enable-unicode \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/pcre2
    make install DESTDIR=/tmp/pcre2
    cd /tmp/pcre2
    rm -fr usr/share/doc/pcre2/html
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/pcre2
    /sbin/ldconfig
}

_build_nghttp2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _nghttp2_ver="$(wget -qO- 'https://github.com/nghttp2/nghttp2/releases' | sed 's|"|\n|g' | grep -i '^/nghttp2/nghttp2/tree' | sed 's|.*/nghttp2-||g' | sed 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sed -e 's|.*tree/||g' -e 's|[Vv]||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/nghttp2/nghttp2/releases/download/v${_nghttp2_ver}/nghttp2-${_nghttp2_ver}.tar.xz"
    tar -xof nghttp2-*.tar*
    sleep 1
    rm -f nghttp2-*.tar*
    cd nghttp2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-lib-only --with-openssl=yes --with-zlib \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/nghttp2
    make install DESTDIR=/tmp/nghttp2
    cd /tmp/nghttp2
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/nghttp2
    /sbin/ldconfig
}

_build_libidn2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libidn2_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/libidn/' | sed 's|"|\n|g' | grep -i '^libidn2-[1-9]' | sed -e 's|libidn2-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sed -e 's|.*tree/||g' -e 's|[Vv]||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://ftp.gnu.org/gnu/libidn/libidn2-${_libidn2_ver}.tar.gz"
    tar -xof libidn2-*.tar.*
    sleep 1
    rm -f libidn2-*.tar*
    cd libidn2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static --disable-doc \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/libidn2
    make install DESTDIR=/tmp/libidn2
    cd /tmp/libidn2
    _strip_files
    sed -e '/^Libs/s/-R[^ ]*//g' -e '/^Libs/s/ *$//' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libidn2
    /sbin/ldconfig
}

_build_libpsl() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libpsl_ver="$(wget -qO- 'https://github.com/rockdaboot/libpsl/releases' | grep -i '/rockdaboot/libpsl/tree/' | sed 's|"|\n|g' | grep -i '^/rockdaboot/libpsl/tree/' | grep -ivE 'alpha|beta|rc[0-9]' | sed 's|.*/tree/||g' | sed 's|libpsl-||g' | sort -V | uniq | tail -n1)"
    wget -c -t 9 -T 9 "https://github.com/rockdaboot/libpsl/releases/download/${_libpsl_ver}/libpsl-${_libpsl_ver}.tar.gz"
    tar -xof libpsl-*.tar*
    sleep 1
    rm -f libpsl-*.tar*
    cd libpsl-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --disable-static --enable-runtime=libidn2 \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/libpsl
    make install DESTDIR=/tmp/libpsl
    cd /tmp/libpsl
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libpsl
    /sbin/ldconfig
}

_build_libffi() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libffi_ver="$(wget -qO- 'https://github.com/libffi/libffi/releases' | grep -i '/libffi/libffi/tree/' | sed 's|"|\n|g' | grep -i '^/libffi/libffi/tree/' | grep -ivE 'alpha|beta|rc[0-9]' | sed 's|.*/tree/v||g' | sort -V | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/libffi/libffi/releases/download/v${_libffi_ver}/libffi-${_libffi_ver}.tar.gz"
    tar -xof libffi-*.tar*
    sleep 1
    rm -f libffi-*.tar*
    cd libffi-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --disable-static --disable-exec-static-tramp \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed '/^toolexeclibdir /s|/\.\./lib||g' -i Makefile
    [[ -f x86_64-pc-linux-gnu/Makefile ]] && sed '/^toolexeclibdir /s|/\.\./lib||g' -i x86_64-pc-linux-gnu/Makefile
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/libffi
    make install DESTDIR=/tmp/libffi
    cd /tmp/libffi
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libffi
    /sbin/ldconfig
}

_build_p11kit() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _p11_kit_ver="$(wget -qO- 'https://github.com/p11-glue/p11-kit/releases' | grep -i 'p11-kit.*tree' | sed 's|"|\n|g' | grep -i '^/p11-glue/p11-kit/tree' | grep -ivE 'alpha|beta|rc' | sed 's|.*/tree/||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 0 -T 9 "https://github.com/p11-glue/p11-kit/releases/download/${_p11_kit_ver}/p11-kit-${_p11_kit_ver}.tar.xz"
    tar -xof p11-kit-*.tar*
    sleep 1
    rm -f p11-kit-*.tar*
    cd p11-kit-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu \
    --host=x86_64-linux-gnu \
    --prefix=/usr \
    --exec-prefix=/usr \
    --sysconfdir=/etc \
    --datadir=/usr/share \
    --includedir=/usr/include \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --libexecdir=/usr/libexec \
    --disable-static \
    --disable-doc --disable-silent-rules \
    --with-trust-paths=/etc/ssl/certs/ca-certificates.crt \
    --with-hash-impl=internal
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/p11kit
    make install DESTDIR=/tmp/p11kit
    cd /tmp/p11kit
    rm -fr usr/share/gtk-doc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/p11kit
    /sbin/ldconfig
}

_build_nettle() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _nettle_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/nettle/' | grep -i 'a href="nettle.*\.tar' | sed 's/"/\n/g' | grep -i '^nettle-.*tar.gz$' | sed -e 's|nettle-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 0 -T 9 "https://ftp.gnu.org/gnu/nettle/nettle-${_nettle_ver}.tar.gz"
    tar -xof nettle-*.tar*
    sleep 1
    rm -f nettle-*.tar*
    cd nettle-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu \
    --includedir=/usr/include --sysconfdir=/etc \
    --enable-shared --enable-static --enable-fat \
    --disable-openssl
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/nettle
    make install DESTDIR=/tmp/nettle
    cd /tmp/nettle
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/nettle
    /sbin/ldconfig
}

_build_gnutls() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _gnutls_ver="$(wget -qO- 'https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/' | grep -i 'a href="gnutls.*\.tar' | sed 's/"/\n/g' | grep -i '^gnutls-.*tar.xz$' | sed -e 's|gnutls-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 0 -T 9 "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-${_gnutls_ver}.tar.xz"
    tar -xof gnutls-*.tar*
    sleep 1
    rm -f gnutls-*.tar*
    cd gnutls-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu \
    --host=x86_64-linux-gnu \
    --enable-shared \
    --enable-threads=posix \
    --enable-sha1-support \
    --enable-ssl3-support \
    --enable-fips140-mode \
    --disable-openssl-compatibility \
    --with-included-unistring \
    --with-included-libtasn1 \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --includedir=/usr/include \
    --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    sed 's| -R/usr/lib/x86_64-linux-gnu||g' -i Makefile
    sed 's| -Wl,-rpath -Wl,/usr/lib/x86_64-linux-gnu||g' -i Makefile
    sed 's| -R/usr/lib/x86_64-linux-gnu||g' -i lib/Makefile
    sed 's| -Wl,-rpath -Wl,/usr/lib/x86_64-linux-gnu||g' -i lib/Makefile
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/gnutls
    make install DESTDIR=/tmp/gnutls
    cd /tmp/gnutls
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/gnutls
    /sbin/ldconfig
}

_build_rtmpdump() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #git clone --recursive 'https://git.ffmpeg.org/rtmpdump.git'
    git clone 'https://github.com/icebluey/rtmpdump.git'
    cd rtmpdump
    rm -fr .git
    #sed -e 's/^CRYPTO=OPENSSL/#CRYPTO=OPENSSL/' -e 's/#CRYPTO=GNUTLS/CRYPTO=GNUTLS/' -i Makefile -i librtmp/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    #make prefix=/usr libdir=/usr/lib/x86_64-linux-gnu OPT="$CFLAGS" XLDFLAGS="$LDFLAGS"
    make prefix=/usr libdir=/usr/lib/x86_64-linux-gnu XLDFLAGS="$LDFLAGS"
    rm -fr /tmp/rtmpdump
    make prefix=/usr libdir=/usr/lib/x86_64-linux-gnu install DESTDIR=/tmp/rtmpdump
    cd /tmp/rtmpdump
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/rtmpdump
    /sbin/ldconfig
}

_build_nghttp3() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #wget -c -t 9 -T 9 "https://github.com/ngtcp2/nghttp3/releases/download/v1.9.0/nghttp3-1.9.0.tar.xz"
    _nghttp3_ver="$(wget -qO- 'https://github.com/ngtcp2/nghttp3/releases' | grep -i '/ngtcp2/nghttp3/tree/' | sed 's|"|\n|g' | grep -i '^/ngtcp2/nghttp3/tree/' | grep -ivE 'alpha|beta|rc[0-9]' | sed 's|.*/tree/[Vv]||g' | sort -V | uniq | tail -n1)"
    wget -c -t 9 -T 9 "https://github.com/ngtcp2/nghttp3/releases/download/v${_nghttp3_ver}/nghttp3-${_nghttp3_ver}.tar.xz"
    tar -xof nghttp3-*.tar*
    sleep 1
    rm -f nghttp3-*.tar*
    cd nghttp3*
    rm -fr .git
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-lib-only \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/nghttp3
    make install DESTDIR=/tmp/nghttp3
    cd /tmp/nghttp3
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/nghttp3
    /sbin/ldconfig
}

_build_ngtcp2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #wget -c -t 9 -T 9 "https://github.com/ngtcp2/ngtcp2/releases/download/v1.12.0/ngtcp2-1.12.0.tar.xz"
    _ngtcp2_ver="$(wget -qO- 'https://github.com/ngtcp2/ngtcp2/releases' | grep -i '/ngtcp2/ngtcp2/tree/' | sed 's|"|\n|g' | grep -i '^/ngtcp2/ngtcp2/tree/' | grep -ivE 'alpha|beta|rc[0-9]' | sed 's|.*/tree/[Vv]||g' | sort -V | uniq | tail -n1)"
    wget -c -t 9 -T 9 "https://github.com/ngtcp2/ngtcp2/releases/download/v${_ngtcp2_ver}/ngtcp2-${_ngtcp2_ver}.tar.xz"
    tar -xof ngtcp2-*.tar*
    sleep 1
    rm -f ngtcp2-*.tar*
    cd ngtcp2*
    rm -fr .git
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --with-boringssl \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/ngtcp2
    make install DESTDIR=/tmp/ngtcp2
    cd /tmp/ngtcp2
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/ngtcp2
    /sbin/ldconfig
}

_build_curl() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _curl_ver="$(wget -qO- 'https://curl.se/download/' | grep -i 'download/curl-[1-9]' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^curl-[1-9].*xz$' | sed -e 's|curl-||g' -e 's|\.tar.*||g' | sort -V | tail -n 1)"
    wget -c -t 0 -T 9 "https://curl.se/download/curl-${_curl_ver}.tar.xz"
    tar -xof curl-*.tar*
    sleep 1
    rm -f curl-*.tar*
    cd curl-*
    LDFLAGS=''
    LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    #LDFLAGS="${_ORIG_LDFLAGS} -Wl,-rpath,/${_private_dir}"; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --with-openssl --with-libssh2 --enable-ares \
    --enable-largefile --enable-versioned-symbols \
    --disable-ldap --disable-ldaps \
    --with-nghttp3 --with-openssl-quic \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(cat /proc/cpuinfo | grep -i '^processor' | wc -l) all
    rm -fr /tmp/curl
    make install DESTDIR=/tmp/curl
    cd /tmp/curl
    rm -f /"${_private_dir}"/libgmpxx.*
    rm -f /"${_private_dir}"/libgnutlsxx.*
    rm -f usr/lib/x86_64-linux-gnu/libcurl.a
    sed 's/-lssh2 -lssh2/-lssh2/g' -i usr/lib/x86_64-linux-gnu/pkgconfig/libcurl.pc
    sed 's/-lssl -lcrypto -lssl -lcrypto/-lssl -lcrypto/g' -i usr/lib/x86_64-linux-gnu/pkgconfig/libcurl.pc
    _strip_files
    #find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' patchelf --add-rpath '$ORIGIN' '{}'
    install -m 0755 -d usr/lib/x86_64-linux-gnu/curl
    cp -afr /"${_private_dir}" usr/lib/x86_64-linux-gnu/curl/
    mv -f usr/lib/x86_64-linux-gnu/libcurl.so* "${_private_dir}"/
    sed "s|^libdir=.*|libdir=/"${_private_dir}"|g" -i usr/lib/x86_64-linux-gnu/pkgconfig/libcurl.pc
    sed -e '/^Libs/s/-R[^ ]*//g' -e '/^Libs/s/ *$//' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    patchelf --add-rpath '$ORIGIN/../lib/x86_64-linux-gnu/curl/private' usr/bin/curl
    echo
    sleep 2
    tar -Jcvf /tmp/curl-"${_curl_ver}"-1_ub2204_amd64.tar.xz *
    echo
    sleep 2
    cd /tmp
    openssl dgst -r -sha256 curl-"${_curl_ver}"-1_ub2204_amd64.tar.xz | sed 's|\*| |g' > curl-"${_curl_ver}"-1_ub2204_amd64.tar.xz.sha256
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/curl
    /sbin/ldconfig
}

############################################################################

rm -fr /usr/lib/x86_64-linux-gnu/curl

_build_zlib
#_build_gmp
_build_cares
_build_brotli

#_build_lz4
#_build_zstd

#_build_libexpat
_build_libunistring

#_build_openssl33
#_build_openssl34
#_build_openssl35

_install_go
_build_aws-lc

_build_libssh2
_build_pcre2

#_build_libffi
#_build_p11kit

_build_libidn2
_build_libpsl
_build_nghttp2

#_build_nettle
#_build_gnutls

_build_rtmpdump
_build_nghttp3
_build_ngtcp2
_build_curl

echo
echo ' build curl done'
echo
exit
