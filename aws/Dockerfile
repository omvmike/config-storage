FROM alpine:3.18

RUN apk --no-cache add \
    bash \
    jq \
    aws-cli \
    coreutils \
    && rm -rf /var/cache/apk/*


COPY aws-config-storage.sh /usr/local/bin/config-storage
RUN chmod +x /usr/local/bin/config-storage

WORKDIR /tmp

ENTRYPOINT ["config-storage"]