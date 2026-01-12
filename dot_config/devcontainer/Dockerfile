ARG VERSION=ubuntu-24.04
FROM mcr.microsoft.com/vscode/devcontainers/base:$VERSION

# Install mise to /usr/local/bin for global access
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# Configure mise environment variables
ENV MISE_DATA_DIR="/mise/data"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
# MEMO : postStartCommandではPATHが通らないためこちらで直接PATH(/mise/data/shims)を指定
ENV PATH="/mise/data/shims:/mise/shims:/mise/installs:$PATH"

COPY mise.toml /mise/config.toml

# Install tools via mise (as root to install globally)
RUN /usr/local/bin/mise install -C /mise && \
    /usr/local/bin/mise reshim -C /mise && \
    /usr/local/bin/mise trust

WORKDIR /workspace

# Ensure proper permissions for mounted volumes
RUN chown -R vscode:vscode /workspace /mise

USER vscode
