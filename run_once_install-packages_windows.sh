#!/bin/bash
[ "$(uname)" != "Linux" ] && exit

install_scoop() {
	if ! command -v scoop &>/dev/null; then
		powershell.exe -c "set-executionpolicy remotesigned -scope currentuser"
		powershell.exe -c "Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')"
	else
		echo "Scoop is already installed"
	fi
}

install_package() {
	local PACKAGES=(
		# https://bun.com/docs/installation#macos-and-linux
		# bun
		git
		gpg
		# go
		# https://mise.jdx.dev/installing-mise.html#apt
		# mise
		ugrep
		zsh
	)

	for package in "${PACKAGES[@]}"; do
		if ! dpkg -l | grep -q "$package"; then
			apt install -y "$package"
		else
			echo "$package is already installed"
		fi
	done
}

install_scoop_package() {
	local PACKAGES=(
		alacritty
		bitwarden
		firefox
		obsidian
		thunderbird
		vscode
	)

	for package in "${PACKAGES[@]}"; do
		if ! scoop list | grep -q "$package"; then
			if [[ "$package" == "alacritty" ]]; then
				scoop install git
				scoop bucket add extras
				scoop install "$package"
			else
				scoop install "$package"
			fi
		else
			echo "$package is already installed"
		fi
	done
}

install_private_scoop_package() {
	local PACKAGES=(
		NeeView
	)

	for package in "${PACKAGES[@]}"; do
		if ! scoop list | grep -q "$package"; then
			scoop install "$package"
		else
			echo "$package is already installed"
		fi
	done
}

install_nix() {
	if ! command -v nix &>/dev/null; then
		# nix-installerでインストール（マルチユーザー非対応のため --no-daemon オプションを使用）
		# https://github.com/DeterminateSystems/nix-installer
		curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --no-confirm
	else
		echo "Nix is already installed"
	fi
}

setup_home_manager() {
	if ! command -v home-manager &>/dev/null; then
		echo "home-managerをインストールしています..."
		nix run home-manager/master -- init --switch --flake "${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi#linux"
	else
		echo "home-managerは既にインストールされています。設定を適用しています..."
		home-manager switch --flake "${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi#linux"
	fi
}

# 実行したいコマンドを入力
commands=(
	"install_scoop"
	"install_package"
	"install_scoop_package"
	"install_private_scoop_package"
	"install_nix"
	# nixインストール後にhome-managerでLinux向けパッケージを管理する場合は有効にする
	# "setup_home_manager"
)

execute_command() {
	local command="$1"

	while true; do
		echo "$command"
		echo "を実行しますか? (y/n)"
		read -r answer

		case "$answer" in
		y | Y)
			eval "$command"
			break
			;;
		n | N)
			break
			;;
		*)
			echo "無効な入力です。y または n を入力してください。"
			;;
		esac
	done
}

for cmd in "${commands[@]}"; do
	execute_command "$cmd"
done
