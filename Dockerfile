FROM debian:bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ARG TARGETARCH=amd64

# ─── Common CLI tools ───────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gcc \
        git \
        jq \
        less \
        make \
        openssh-client \
        procps \
        sudo \
        tar \
        tzdata \
        unzip \
        wget \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# ─── Python 3 ---────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        python3-dev \
        python3-pip \
        pipx \
        libffi-dev \
    && pip install --break-system-packages pipenv uv \
    && rm -rf /var/lib/apt/lists/*

# ─── Node.js 22 LTS (NodeSource) ────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# ─── Go 1.26 ────────────────────────────────────────────────────
ARG GO_VERSION=1.26.8
ARG GOLANG_LINT_VERSION=v2.14.0
RUN case "$TARGETARCH" in \
        amd64|arm64) GOOS="linux"; GOARCH="$TARGETARCH" ;; \
        *)           GOOS="linux"; GOARCH="amd64"  ;; \
    esac && \
    curl -fsSL --retry 3 "https://go.dev/dl/go${GO_VERSION}.${GOOS}-${GOARCH}.tar.gz" \
      -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:/root/go/bin:/usr/local/bin:${PATH}"
RUN go version
RUN go install golang.org/x/tools/cmd/goimports@latest && \
    go install honnef.co/go/tools/cmd/staticcheck@latest && \
    curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/${GOLANG_LINT_VERSION}/install.sh | sh -s -- -b /root/go/bin ${GOLANG_LINT_VERSION}

# ─── Docker CLI ──────────────────────────────────────────────────
ARG DOCKER_CLI_VERSION=29.8.1
RUN case "$TARGETARCH" in \
        amd64)   DOCKER_ARCH="x86_64" ;; \
        arm64)   DOCKER_ARCH="aarch64" ;; \
        *)       DOCKER_ARCH="x86_64"  ;; \
    esac && \
    curl -fsSL --retry 3 "https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_CLI_VERSION}.tgz" \
      -o /tmp/docker.tgz && \
    tar -xzf /tmp/docker.tgz docker && \
    mv docker/docker /usr/local/bin/docker && \
    chmod +x /usr/local/bin/docker && \
    rm -rf docker /tmp/docker.tgz

# ─── Cleanup ────────────────────────────────────────────────────
RUN rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# ─── Persist Go on PATH after /etc/profile resets it ────────────
RUN printf 'export PATH="/usr/local/go/bin:/root/go/bin:/usr/local/bin:$PATH"\n' > /etc/profile.d/go.sh
