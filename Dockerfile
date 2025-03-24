ARG GOLANG_VERSION=1.24.1
ARG ALPINE_VERSION=3.21.3
ARG TEMPO_VERSION=v2.7.1

FROM golang:${GOLANG_VERSION} AS builder

ARG TEMPO_VERSION
ENV TEMPO_VERSION=${TEMPO_VERSION}

RUN apt-get install -y git=1:2.39.5-0+deb12u2 --no-install-recommends && \
    git clone --depth 1 --branch $TEMPO_VERSION https://github.com/grafana/tempo.git

WORKDIR /go/tempo

RUN GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
    GIT_REVISION=$(git rev-parse --short HEAD) && \
    CGO_ENABLED=0 GOAMD64=v2 go build \
    -mod vendor \
    -ldflags "-X main.Branch=$GIT_BRANCH -X main.Revision=$GIT_REVISION -X main.Version=$TEMPO_VERSION -w" \
    -o ./bin/linux/tempo-amd64 ./cmd/tempo

FROM alpine:${ALPINE_VERSION} AS ca-certificates
RUN apk add --update --no-cache ca-certificates=20241121-r1

FROM gcr.io/distroless/static-debian12:debug

COPY --from=builder /go/tempo/bin/linux/tempo-amd64 /tempo
COPY --from=ca-certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

SHELL ["/busybox/sh", "-c"]
RUN ["/busybox/addgroup", "-g", "10001", "-S", "tempo"]
RUN ["/busybox/adduser", "-u", "10001", "-S", "tempo", "-G", "tempo"]
RUN ["/busybox/mkdir", "-p", "/var/tempo", "-m", "0700"]
RUN ["/busybox/chown", "-R", "tempo:tempo", "/var/tempo"]

USER 10001:10001

ENTRYPOINT ["/tempo"]