FROM alpine:edge
MAINTAINER Mickaël Perrin <dev@mickaelperrin.fr>

# Add edge repos
RUN echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories; \
    echo "@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories; \
    echo "@edgetesting http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

ARG UNISON_VERSION=2.51.2

# Compile unison from source with inotify support and removes compilation tools
RUN apk add --no-cache --virtual .build-dependencies build-base curl \
 && apk add --no-cache inotify-tools su-exec bash \
 && apk add --no-cache ocaml@edge \
 && curl -L https://github.com/bcpierce00/unison/archive/v$UNISON_VERSION.tar.gz | tar zxv -C /tmp \
 && cd /tmp/unison-${UNISON_VERSION} \
 && sed -i -e 's/GLIBC_SUPPORT_INOTIFY 0/GLIBC_SUPPORT_INOTIFY 1/' src/fsmonitor/linux/inotify_stubs.c \
 && make UISTYLE=text NATIVE=true STATIC=true \
 && cp src/unison src/unison-fsmonitor /usr/local/bin \
 && apk del .build-dependencies ocaml \
 && rm -rf /tmp/unison-${UNISON_VERSION}

# Install entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN mkdir -p /docker-entrypoint.d \
 && chmod +x /docker-entrypoint.sh

ENV TZ="Europe/Paris" \
    LANG="C.UTF-8"

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["unison"]