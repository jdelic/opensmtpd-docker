FROM alpine:3.10.1 as build

WORKDIR /opensmtpd

# libressl is used for testing only
RUN apk add --no-cache \
    ca-certificates \
    automake \
    autoconf \
    libtool \
    gcc \
    make \
    musl-dev \
    bison \
    libevent-dev \
    libtool \
    libasr-dev \
    fts-dev \
    zlib-dev \
    libressl-dev \
    libressl \
    git \
    unzip \
    sqlite-dev \
    postgresql-dev \
    mariadb-dev \
    hiredis-dev \
    perl-dev \
    python-dev \
    libevent-dev

# For testing
RUN mkdir -p /var/lib/opensmtpd/empty/ && \
    adduser _smtpd -h /var/lib/opensmtpd/empty/ -D -H -s /bin/false && \
    adduser _smtpq -h /var/lib/opensmtpd/empty/ -D -H -s /bin/false && \
    mkdir -p /var/spool/smtpd && \
    chmod 711 /var/spool/smtpd

RUN wget https://github.com/OpenSMTPD/OpenSMTPD/archive/opensmtpd-6.4.2p1.zip && \
    unzip opensmtpd-6.4.2p1.zip && \
    mv OpenSMTPD-opensmtpd-6.4.2p1 opensmtpd && \
    git clone https://github.com/opensmtpd/opensmtpd-extras

# build opensmtpd
RUN rm -r /usr/local/ && \
    cd /opensmtpd/opensmtpd && \
    ./bootstrap && \
    ./configure --with-gnu-ld --sysconfdir=/etc/mail --with-path-empty=/var/lib/opensmtpd/empty/ && \
    make && \
    make install

# build opensmtpd-extras
# removed: --with-table-ldap \
RUN cd /opensmtpd/opensmtpd-extras && \
    ./bootstrap && \
    ./configure --with-gnu-ld --with-user-smtpd=_smtpd \
        --with-filter-monkey \
        --with-filter-stub \
        --with-filter-trace \
        --with-filter-void \
        --with-queue-null \
        --with-queue-python \
        --with-queue-ram \
        --with-queue-stub \
        --with-table-mysql \
        --with-table-postgres \
        --with-table-redis \
        --with-table-socketmap \
        --with-table-passwd \
        --with-table-python \
        --with-table-sqlite \
        --with-table-stub \
        --with-tool-stats \
        --with-scheduler-ram \
        --with-scheduler-stub \
        --with-scheduler-python && \
    make && \
    make install


FROM alpine:3.10.1
LABEL maintainer="Jonas Maurus <jdelic>"

EXPOSE 25
EXPOSE 465
EXPOSE 587

VOLUME /etc/mail
VOLUME /var/spool/smtpd
WORKDIR /var/spool/smtpd

ENTRYPOINT ["smtpd", "-d"]
CMD ["-P", "mda"]

RUN apk add --no-cache \
        libressl \
        libevent \
        libasr \
        fts \
        zlib \
        ca-certificates \
        sqlite \
        libpq \
        mariadb-client \
        hiredis \
        python2 && \
    mkdir -p /var/lib/opensmtpd/empty/ && \
    adduser _smtpd -h /var/lib/opensmtpd/empty/ -D -H -s /bin/false && \
    adduser _smtpq -h /var/lib/opensmtpd/empty/ -D -H -s /bin/false && \
    mkdir -p /etc/mail/ && \
    mkdir -p /var/spool/smtpd && \
    chmod 711 /var/spool/smtpd

COPY --from=build /usr/local/ /usr/local/
COPY --from=build /opensmtpd/opensmtpd/smtpd/smtpd.conf /etc/mail

#OpenSMTPD needs root permissions to open port 25.
#It immediately changes to running as _smtpd after that.
