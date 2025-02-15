# Build stage
FROM golang:1.21 as build-env

WORKDIR /src

RUN set -ex && \
        export DEBIAN_FRONTEND=noninteractive; \
        apt-get -q update && apt-get install -y --no-install-recommends bash curl make git

COPY . .

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o /app/sbin/gluster-exporter ./gluster-exporter

# Create small image for running
FROM debian:bookworm-slim

ARG GLUSTER_VERSION=10

# Install gluster cli for gluster-exporter
RUN set -ex && \
        export DEBIAN_FRONTEND=noninteractive; \
        apt-get -q update && apt-get install -y --no-install-recommends gnupg curl apt-transport-https ca-certificates && \
        DEBID=$(grep 'VERSION_ID=' /etc/os-release | cut -d '=' -f 2 | tr -d '"') && \
        DEBVER=$(grep 'VERSION=' /etc/os-release | grep -Eo '[a-z]+') && \
        DEBARCH=$(dpkg --print-architecture) && \
        curl -sSL http://download.gluster.org/pub/gluster/glusterfs/${GLUSTER_VERSION}/rsa.pub | apt-key add - && \
        echo deb https://download.gluster.org/pub/gluster/glusterfs/${GLUSTER_VERSION}/LATEST/Debian/${DEBID}/${DEBARCH}/apt ${DEBVER} main > /etc/apt/sources.list.d/gluster.list && \
        apt-get -q update && apt-get install -y --no-install-recommends glusterfs-server && apt-get clean all && \
        rm -Rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

COPY --from=build-env /app /app/

ENTRYPOINT ["/app/sbin/gluster-exporter"]
