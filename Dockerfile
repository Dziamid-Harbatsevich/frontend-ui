FROM alpine:3.24

ENV NODE_VERSION=26.12.1

# 1. Install Node.js runtime and clean up build dependencies
RUN addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libatomic \
        libstdc++ \
        python3 \
    && apk add --no-cache --virtual .build-deps \
        gnupg \
        curl \
    && ARCH= OPENSSL_ARCH='linux*' && alpineArch="$(apk --print-arch)" \
    && case "${alpineArch##*-}" in \
        x86_64) ARCH='x64' OPENSSL_ARCH=linux-x86_64;; \
        aarch64) OPENSSL_ARCH=linux-aarch64;; \
        *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    && export GNUPGHOME="$(mktemp -d)" \
    && set -ex \
    && for key in \
        5BE8A3F6C8A5C01D106C0AD820B1A390B168D356 \
        DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
        CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
        890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
        C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
        108F52B48DB57BB0CC439B2997B01419BD92F80A \
        655F3B5C1FB3FA8D1A0CA6BDE4A7D232B936D2FD \
        A363A499291CBBC940DD62E41F10027AF002F8B0 \
    ; do \
        { gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" && gpg --batch --fingerprint "$key"; } || \
        { gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" && gpg --batch --fingerprint "$key"; } ; \
    done \
  && if [ "$ARCH" = "x64" ] || [ "$ARCH" = "aarch64" ]; then \
    curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && grep " node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "node-v$NODE_VERSION-linux-$ARCH-musl.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
  else \
    echo "Building from source" \
    && apk add --no-cache --virtual .build-deps-full \
        binutils-gold \
        g++ \
        gcc \
        libgcc \
        linux-headers \
        make \
        python3 \
        py-setuptools \
        rust \
        cargo \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j"$(getconf _NPROCESSORS_ONLN)" V= \
    && make install \
    && apk del .build-deps-full \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt; \
  fi \
  && find /usr/local/include/node/openssl/archs -mindepth 1 -maxdepth 1 ! -name "$OPENSSL_ARCH" -exec rm -rf {} \; \
  && apk del .build-deps \
  && node --version \
  && npm --version \
  && rm -rf /tmp/*

# 2. Install production compatibility libraries
RUN apk add --no-cache libc6-compat

# 3. Setup application directory & build dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# 4. Copy configuration scripts and source files
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# 5. Expose hot-reloading configurations & internal ports
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
ENV WATCHPACK_POLLING=true
EXPOSE 3000

# 6. Define runtime execution context (Kept at the very bottom)
ENTRYPOINT ["entrypoint.sh"]
CMD ["npm", "run", "dev"]
