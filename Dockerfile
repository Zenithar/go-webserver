# --------------------------------------------------------------
FROM golang:1.14 as builder

RUN set -eux; \
	apt-get update -y && \
	apt-get install -y apt-utils upx;

# Replace Go with boringssl build.
RUN rm -Rf /usr/local/go && cd /usr/local && curl https://go-boringcrypto.storage.googleapis.com/go1.14.1b4.linux-amd64.tar.gz | tar xz;

RUN go version

# Create a non-root privilege account to build
RUN adduser --disabled-password --gecos "" -u 1000 golang && \
    mkdir -p $GOPATH/src/workspace && \
    chown -R golang:golang $GOPATH/src/workspace;

ENV GOPROXY=https://proxy.golang.org/

WORKDIR $GOPATH/src/workspace

# Clean go cache
RUN go clean --cache && go clean --modcache

# Drop privileges to build
USER golang

# Copy source
COPY --chown=golang:golang . .

# Build hardened binary
RUN go mod tidy && go mod vendor \
	&& go build -buildmode=pie -tags netgo -installsuffix netgo --ldflags="-s -w" -o bin/caddy \
	&& chmod +x bin/caddy

RUN ldd bin/caddy

# Compress binaries
RUN set -eux; \
    upx -9 bin/* && \
    chmod +x bin/*

# --------------------------------------------------------------
FROM gcr.io/distroless/base:latest

# Metadata
LABEL \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="CaddyServer" \
    org.label-schema.description="Custom prepared caddy webserver" \
    org.label-schema.url="https://go.zenithar.org/webserver" \
    org.label-schema.vcs-url="https://github.com/Zenithar/go-webserver.git" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vendor="Thibault NORMAND" \
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0" \
    org.zenithar.licence="APL2"

COPY --from=builder --chown=root:root /go/src/workspace/bin/caddy /usr/bin/

USER nobody:nobody

ENTRYPOINT [ "/usr/bin/caddy" ]
CMD [ "-h" ]
