# devcontainer 用の image。
#
# build context は ~/.config/devcontainer ではなく、initializeCommand
# （scripts/initialize.sh）が symlink を解決して作る
# ~/.cache/devcontainer/host-config/devcontainer を使う。
# ~/.config 配下は mise の [dotfiles] が symlink-each で配置するため、そのまま context に
# すると BuildKit がコンテキスト外を指す symlink を辿れず、下の COPY が "not found" で
# 失敗する（docs/devcontainer.md 参照）。レイアウトは ~/.config/devcontainer と同じなので
# COPY のパスはそのまま使える。
ARG VERSION=ubuntu-24.04
FROM mcr.microsoft.com/vscode/devcontainers/base:$VERSION


# apt のパッケージリストと .deb は BuildKit の cache mount に置く（layer に残らないので
# apt-get clean / rm -rf /var/lib/apt/lists/* は不要。Dockerfile.sandbox と同じ）。
# docker-clean は install 後に .deb を消して cache を無効にするため外しておく。
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && apt-get install -y \
    rsync \
    zsh
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
# crit ラッパー（~/.config/devcontainer/scripts/crit, bind-mount）を mise shim より
# 前に置き、pristine な crit skill の `crit` 呼び出しがラッパー経由になるようにする。
# 詳細は docs/crit.md 参照。
ENV PATH=/home/vscode/.config/devcontainer/scripts:$PATH

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

# mise.toml が変わるとこの RUN は必ず再実行されるが、全ツールを毎回ゼロから入れ直すと遅いため、
# インストール済みツール(/mise/data)を BuildKit の cache mount(/mise/data-cache)に保存しておき、
# 次回ビルド時に復元してから `mise install` する。これにより差分（バージョンが変わったツール）だけが
# ダウンロード/ビルドされる。
# - install 先のパスは常に /mise/data のまま（shim や shebang の絶対パスが壊れないよう、
#   cache mount を直接 MISE_DATA_DIR にはせず rsync で出し入れする）。
# - 復元した古いバージョンは `mise prune` で消し、イメージには mise.toml のバージョンだけを残す。
# - sharing=locked で multi-worktree の同時ビルドによる cache 破損を防ぐ。
# - go / bun のダウンロード・ビルドキャッシュも cache mount(/mise/cache) 配下に置いて再利用する。
# cache mount は `docker builder prune` で消える（消えても初回と同じフルインストールになるだけ）。
#
# gh を最初に入れるのは bootstrap のため（gh 未インストール時は `gh auth token` が使えないので
# GITHUB_TOKEN を secret から渡す）。
# /run/secrets/github_token は、この RUN の --mount=type=secret,id=github_token によって
# BuildKit が作るファイル。devcontainer.json の build.options (--secret id=github_token,env=GH_TOKEN)
# でホストの GH_TOKEN の値がこの secret として渡され、BuildKit がこの RUN ステップの実行中だけ
# /run/secrets/github_token として展開する。イメージの layer には残らず、この RUN が終われば消える。
RUN --mount=type=secret,id=github_token,uid=1000,gid=1000,mode=0400 \
    --mount=type=cache,id=devcontainer-mise-cache,target=/mise/cache,uid=1000,gid=1000 \
    --mount=type=cache,id=devcontainer-mise-data,target=/mise/data-cache,uid=1000,gid=1000,sharing=locked \
    set -eu; \
    export GITHUB_TOKEN="$(cat /run/secrets/github_token)" \
      MISE_YES=1 \
      GOMODCACHE=/mise/cache/go-mod \
      GOCACHE=/mise/cache/go-build \
      GOFLAGS=-modcacherw \
      BUN_INSTALL_CACHE_DIR=/mise/cache/bun; \
    rsync -a /mise/data-cache/ /mise/data/; \
    /usr/local/bin/mise install -C /mise aqua:cli/cli; \
    /usr/local/bin/mise reshim -C /mise; \
    /usr/local/bin/mise install -C /mise; \
    /usr/local/bin/mise prune -C /mise --tools || echo "warn: mise prune failed" >&2; \
    rm -rf /mise/data/downloads; \
    /usr/local/bin/mise reshim -C /mise; \
    rsync -a --delete /mise/data/ /mise/data-cache/; \
    /usr/local/bin/mise trust /mise/config.toml

# gh stack（github/gh-stack）は gh の公式 extension として入れる。gh 2.102 以降の `stack` は
# 「extension を入れてください」と出すだけの組み込みコマンドで、extension があればそちらが
# 優先される。mise には gh extension の backend が無いので、ここで `gh extension install` する。
# 入り先は ~/.local/share/gh/extensions で、read-only mount される ~/.config/gh とは別なので
# 実行時もそのまま見える。GH_CONFIG_DIR は使い捨てにして image に設定を残さない。
# renovate: datasource=github-releases depName=github/gh-stack
ARG GH_STACK_VERSION=v0.2.0
RUN --mount=type=secret,id=github_token,uid=1000,gid=1000,mode=0400 \
    set -eu; \
    gh_config="$(mktemp -d)"; \
    GH_TOKEN="$(cat /run/secrets/github_token)" GH_CONFIG_DIR="$gh_config" \
      /mise/data/shims/gh extension install github/gh-stack --pin "$GH_STACK_VERSION"; \
    rm -rf "$gh_config"

# tasks の変更で上の重い install layer が無効化されないよう、install の後に COPY する。
COPY --chown=vscode:vscode tasks /mise/tasks

WORKDIR /workspace
