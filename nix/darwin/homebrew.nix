{ ... }:
{
  homebrew = {
    enable = true;

    # アップデート時に未定義のパッケージを自動削除する
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    # brew tap（追加リポジトリ）
    taps = [
      "oven-sh/bun"
      "kamillobinski/thock"
      "ankitpokhrel/jira-cli"
    ];

    # brew install（CLIツール）
    brews = [
      "oven-sh/bun/bun"
      "blueutil"
      "git"
      "go"
      "gpg"
      "mise"
      "pinentry-mac"
      "silicon"
      "ugrep"
      "coreutils"
      "findutils"
      "gnu-sed"
      "grep"
      "tree"
      # Work用
      "ankitpokhrel/jira-cli/jira-cli"
    ];

    # brew install --cask（GUIアプリ）
    casks = [
      "alacritty"
      "arc"
      "battery"
      "chatgpt"
      "clibor"
      "dbeaver-community"
      "docker"
      "firefox"
      "ghostty"
      "google-chrome"
      "google-japanese-ime"
      "karabiner-elements"
      "keyboardcleantool"
      "raycast"
      "slack"
      "thock"
      "visual-studio-code"
      "wezterm@nightly"
      "zoom"
      # Private
      "bitwarden"
      "claude"
      "google-drive"
      "obsidian"
      "tailscale"
      "termius"
      "thunderbird"
      # Work
      "inkscape"
    ];

    # フォント
    # font-hackgen, font-hackgen-nerd は homebrew-cask-fonts から
    # Note: homebrew/cask-fontsのtapが必要
    masApps = { };
  };
}
