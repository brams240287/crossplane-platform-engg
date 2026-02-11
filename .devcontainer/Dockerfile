# Crossplane Platform Engineering Development Container
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# === STEP 1: Install corporate CA certificate FIRST ===
# Create directory and copy certificate
RUN mkdir -p /usr/local/share/ca-certificates/
COPY .devcontainer/corporate-ca.crt /usr/local/share/ca-certificates/corporate-ca.crt
RUN chmod 644 /usr/local/share/ca-certificates/corporate-ca.crt

# Update CA store BEFORE any network operations
RUN apt-get update \
    && apt-get install -y ca-certificates \
    && update-ca-certificates --fresh \
    && echo "✅  CA certificate installed"

# === STEP 2: Set ALL certificate environment variables ===
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
ENV GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
ENV AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV PERL_LWP_SSL_CA_FILE=/etc/ssl/certs/ca-certificates.crt

# Also add to environment for all users
RUN echo 'export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt' >> /etc/environment \
    && echo 'export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt' >> /etc/environment \
    && echo 'export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt' >> /etc/environment

# === STEP 3: Install base dependencies with trusted CA ===
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    build-essential \
    unzip \
    jq \
    vim \
    nano \
    sudo \
    bash-completion \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create vscode user with sudo access
RUN useradd -m -s /bin/bash -G sudo vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# === STEP 4: Install tools with certificate trust ===
# Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL --cacert /etc/ssl/certs/ca-certificates.crt https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# kubectl with explicit CA
RUN KUBECTL_VERSION="v1.29.0" \
    && curl --cacert /etc/ssl/certs/ca-certificates.crt -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Helm with explicit CA
RUN HELM_VERSION="v3.13.3" \
    && curl --cacert /etc/ssl/certs/ca-certificates.crt -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
    && tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && rm -rf linux-amd64 helm-${HELM_VERSION}-linux-amd64.tar.gz

# kind with explicit CA
RUN curl --cacert /etc/ssl/certs/ca-certificates.crt -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 \
    && chmod +x /usr/local/bin/kind

# Azure CLI - may need alternative approach (see below)
RUN curl --cacert /etc/ssl/certs/ca-certificates.crt -sL https://aka.ms/InstallAzureCLIDeb | bash

# Go
ENV GO_VERSION=1.21.6
RUN wget --ca-certificate=/etc/ssl/certs/ca-certificates.crt -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz \
    && rm go${GO_VERSION}.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:/home/vscode/go/bin:${PATH}"
ENV GOPATH="/home/vscode/go"

# Python 3.11
RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20
RUN curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# yq
RUN wget --ca-certificate=/etc/ssl/certs/ca-certificates.crt -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq

# Crossplane CLI (crank)
RUN CROSSPLANE_VERSION="v2.1.4" \
    && curl --cacert /etc/ssl/certs/ca-certificates.crt -sLo /usr/local/bin/crossplane "https://releases.crossplane.io/stable/${CROSSPLANE_VERSION}/bin/linux_amd64/crank" \
    && chmod +x /usr/local/bin/crossplane

# Shellcheck and yamllint
RUN apt-get update && apt-get install -y shellcheck \
    && pip3 install --no-cache-dir yamllint \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Nushell
RUN NUSHELL_VERSION="0.99.1" \
    && wget --ca-certificate=/etc/ssl/certs/ca-certificates.crt -qO /tmp/nushell.tar.gz "https://github.com/nushell/nushell/releases/download/${NUSHELL_VERSION}/nu-${NUSHELL_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    && tar -xzf /tmp/nushell.tar.gz -C /tmp \
    && mv /tmp/nu-${NUSHELL_VERSION}-x86_64-unknown-linux-gnu/nu /usr/local/bin/nu \
    && chmod +x /usr/local/bin/nu \
    && rm -rf /tmp/nushell.tar.gz /tmp/nu-${NUSHELL_VERSION}-x86_64-unknown-linux-gnu

# Switch to vscode user
USER vscode
WORKDIR /home/vscode

# Install Python packages
RUN pip3 install --user --no-cache-dir \
    mkdocs \
    mkdocs-material \
    mkdocs-mermaid2-plugin \
    pymdown-extensions \
    beautifulsoup4

# Install Go tools
RUN go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest

# Set up bash completion
RUN echo 'source /usr/share/bash-completion/bash_completion' >> ~/.bashrc \
    && echo 'source <(kubectl completion bash)' >> ~/.bashrc \
    && echo 'alias k=kubectl' >> ~/.bashrc \
    && echo 'complete -F __start_kubectl k' >> ~/.bashrc \
    && echo 'alias kgp="kubectl get providers"' >> ~/.bashrc \
    && echo 'alias kgc="kubectl get compositions"' >> ~/.bashrc \
    && echo 'alias kgxrd="kubectl get xrd"' >> ~/.bashrc

# Set environment variables
ENV CROSSPLANE_NAMESPACE=crossplane-system
ENV KUBECONFIG=/home/vscode/.kube/config
ENV PATH="/home/vscode/.local/bin:${PATH}"

# Create workspace directory
RUN mkdir -p /home/vscode/workspace

# Set the default working directory
WORKDIR /home/vscode/workspace

# Keep container running
CMD ["/bin/bash"]