FROM debian:bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ARG TARGETARCH=amd64

# ─── Common CLI tools ───────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        gcc \
        gettext \
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
        yq \
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
ENV PATH="/usr/local/go/bin:/usr/local/bin:${PATH}"
ENV GOBIN="/usr/local/bin"
RUN go version
RUN go install golang.org/x/tools/cmd/goimports@latest && \
    go install honnef.co/go/tools/cmd/staticcheck@latest && \
    curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/${GOLANG_LINT_VERSION}/install.sh | sh -s -- -b /usr/local/bin ${GOLANG_LINT_VERSION}

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

# ─── kubectl ──────────────────────────────────────────────────
ARG HELM_VERSION=3.2.1
ARG KUBECTL_VERSION=1.17.5
ARG KUSTOMIZE_VERSION=v3.8.1
ARG KREW_VERSION=v0.4.4

ARG ARCH=amd64

RUN curl -sL https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz | tar -xvz && \
    mv linux-${ARCH}/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-${ARCH}

RUN curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

RUN curl -sLO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz && \
    tar xvzf kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz && \
    mv kustomize /usr/bin/kustomize && \
    chmod +x /usr/bin/kustomize && \
    rm kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz

# ─── Cleanup ────────────────────────────────────────────────────
RUN rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# ─── Persist Go on PATH after /etc/profile resets it ────────────
RUN printf 'export PATH="/usr/local/go/bin:/usr/local/bin:/root/.krew/bin:$PATH"\n' > /etc/profile.d/go.sh
