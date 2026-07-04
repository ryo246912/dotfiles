ARG VERSION=ubuntu-24.04
FROM mcr.microsoft.com/vscode/devcontainers/base:$VERSION


RUN apt-get update && apt-get install -y \
    zsh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
ENV SHELL=/usr/bin/zsh
#set default shell to zsh
RUN chsh -s /bin/zsh

# Install mise to /usr/local/bin for global access
RUN curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# Configure mise environment variables
ENV MISE_DATA_DIR=/mise/data
ENV MISE_CONFIG_DIR=/mise
ENV MISE_STATE_DIR=/mise/state
ENV MISE_CACHE_DIR=/mise/cache
# MEMO : postStartCommandではPATHが通らないためこちらで直接PATH(/mise/data/shims)を指定
ENV PATH=/mise/data/shims:/mise/shims:/mise/installs:$PATH

RUN install -d -o vscode -g vscode \
    /mise \
    /mise/cache \
    /mise/data \
    /mise/state \
    /workspace \
    /home/vscode/.local \
    /home/vscode/.config \
    /home/vscode/.config/gh
COPY --chown=vscode:vscode mise.toml /mise/config.toml

USER vscode

# First, install gh so the authenticated install can read the mounted token config
RUN --mount=type=cache,target=/mise/cache,uid=1000,gid=1000 \
    /usr/local/bin/mise install -C /mise aqua:cli/cli && \
    /usr/local/bin/mise reshim -C /mise

# Install all tools via mise with GitHub auth available
RUN --mount=type=secret,id=gh_config,target=/home/vscode/.config/gh/config.yml,uid=1000,gid=1000,mode=0400 \
    --mount=type=cache,target=/mise/cache,uid=1000,gid=1000 \
    GITHUB_TOKEN="$(gh auth token)" /usr/local/bin/mise install -C /mise && \
    /usr/local/bin/mise reshim -C /mise && \
    /usr/local/bin/mise trust /mise/config.toml

USER root

# install tool via curl
RUN curl -fsSL https://cli.coderabbit.ai/install.sh | sh

USER vscode

WORKDIR /workspace
