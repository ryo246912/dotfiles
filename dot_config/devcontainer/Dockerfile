ARG VERSION=ubuntu-24.04
FROM mcr.microsoft.com/vscode/devcontainers/base:$VERSION


RUN apt-get update && apt-get install -y \
    zsh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
ENV SHELL /usr/bin/zsh
#set default shell to zsh
RUN chsh -s /bin/zsh

# Install mise to /usr/local/bin for global access
RUN MISE_VERSION=v2026.2.13 curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# Configure mise environment variables
ENV MISE_DATA_DIR="/mise/data"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_STATE_DIR="/mise/state"
ENV MISE_CACHE_DIR="/mise/cache"
# MEMO : postStartCommandではPATHが通らないためこちらで直接PATH(/mise/data/shims)を指定
ENV PATH="/mise/data/shims:/mise/shims:/mise/installs:$PATH"
COPY mise.toml /mise/config.toml

# First, install gh
RUN /usr/local/bin/mise install -C /mise aqua:cli/cli && \
    /usr/local/bin/mise reshim -C /mise

# Install all tools via mise with GitHub auth available
RUN --mount=type=secret,id=gh_config,target=/home/vscode/.config/gh/config.yml \
    /usr/local/bin/mise install -C /mise aqua:cli/cli && \
    GITHUB_TOKEN=$(gh auth token) /usr/local/bin/mise install -C /mise && \
    /usr/local/bin/mise reshim -C /mise && \
    /usr/local/bin/mise trust

# install tool via curl
RUN curl -fsSL https://cli.coderabbit.ai/install.sh | sh

WORKDIR /workspace

# Ensure proper permissions for mounted volumes
RUN mkdir -p /home/vscode/.local /home/vscode/.config \
    && chown -R vscode:vscode /workspace /mise /home/vscode/.local /home/vscode/.config

USER vscode
