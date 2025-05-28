{
  description = "A very basic flake";

  # 取得先
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # inputの内容を引数に追加
  outputs = {
    self,
    nixpkgs,
    nix-darwin,
  }:
  let
    system = "aarch64-darwin";
    hostname = "v22050"; # hostnameの実行内容
  in
  {
    darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
      inherit system;

      # https://nix-darwin.github.io/nix-darwin/manual/index.html
      modules = [
        {
          system = {
            stateVersion = 5;

            defaults = {
              finder = {
                # 隠しファイルを表示する
                AppleShowAllFiles = true;
                # 拡張子を表示する
                AppleShowAllExtensions = true;
                # パスのパンくずリストを表示する
                ShowPathbar = true;
              };

              dock = {
                tilesize = 64;
                autohide = true;
                mineffect = "scale";
                # アプリは/Applications,/System/Applicationsの内容を指定
                persistent-apps = [
                  { app = "/Applications/Arc.app"; }
                  { app = "/Applications/Alacritty.app"; }
                  { app = "/Applications/Slack.app"; }
                  { app = "/Applications/DBeaver.app"; }
                  { app = "/System/Applications/Utilities/Activity Monitor.app"; }
                  { app = "/System/Applications/Launchpad.app"; }
                ];
              };

              # キーボードの設定
              NSGlobalDomain = {
                # キーのリピート速度
                KeyRepeat = 2;
                # リピート入力認識までの時間
                InitialKeyRepeat = 15;  # 15ms
                # トラックパッドのNatural scrollingの設定 = スクロール方向をあわせる
                "com.apple.swipescrolldirection" = false;
              };
            };

            # シェルスクリプトを実行するためのカスタムスクリプト
          #   activationScripts.script.text = ''
          #     #!/bin/bash

          #     # メニューバーの感覚を狭める
          #     if ! defaults -currentHost read -globalDomain NSStatusItemSpacing &>/dev/null || [ "$(defaults -currentHost read -globalDomain NSStatusItemSpacing)" -ne 6 ]; then
          #       defaults -currentHost write -globalDomain NSStatusItemSpacing -int 6
          #     fi
          #     if ! defaults -currentHost read -globalDomain NSStatusItemSelectionPadding &>/dev/null || [ "$(defaults -currentHost read -globalDomain NSStatusItemSelectionPadding)" -ne 6 ]; then
          #       defaults -currentHost write -globalDomain NSStatusItemSelectionPadding -int 6
          #     fi

          #     # ログイン時に開く
          #     {
          #       if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q "Clibor"; then
          #         osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Clibor.app", hidden:false}'
          #       fi
          #     } &

          #     {
          #       if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q "Docker"; then
          #         osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Docker.app", hidden:false}'
          #       fi
          #     } &

          #     {
          #       if ! osascript -e 'tell application "System Events" to get the name of every login item' | grep -q "Raycast"; then
          #         osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Raycast.app", hidden:false}'
          #       fi
          #     } &

          #     wait
          #   '';
          # };

          nix = {
            optimise.automatic = true;

            settings = {
              experimental-features = "nix-command flakes";
            };
          };
        }
      ];
    };
  };
}
