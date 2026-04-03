{ pkgs, ... }:
{
  imports = [
    ./homebrew.nix
  ];

  # Nix設定
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # 並列ビルド数
    max-jobs = "auto";
  };

  # nix-darwinが自身を管理できるようにする
  programs.zsh.enable = true;

  # macOSシステムデフォルト設定
  system.defaults = {
    finder = {
      # 隠しファイルを表示する
      AppleShowAllFiles = true;
      # 拡張子を表示する
      AppleShowAllExtensions = true;
      # パスのパンくずリストを表示する
      ShowPathbar = true;
      # Finderを終了するメニューを表示する
      QuitMenuItem = true;
    };
    NSGlobalDomain = {
      # キーのリピート速度（小さいほど速い）
      KeyRepeat = 2;
      # リピート入力認識までの時間
      InitialKeyRepeat = 15;
      # スクロール方向（falseが自然な方向）
      "com.apple.swipescrolldirection" = false;
    };
  };

  # nix-darwinのシステムバージョン（変更不要）
  system.stateVersion = 5;
}
