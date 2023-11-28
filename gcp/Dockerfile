FROM google/cloud-sdk:409.0.0-alpine

RUN apk update \
    && apk add jq


COPY gcp-config-storage.sh /usr/local/bin/config-storage
RUN chmod +x /usr/local/bin/config-storage

WORKDIR /tmp

ENTRYPOINT ["config-storage"]