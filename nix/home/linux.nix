{ pkgs, ... }:
{
  home = {
    username = "ryo.";
    homeDirectory = "/home/ryo.";
    stateVersion = "24.11";
  };

  # home-managerが自身を管理できるようにする
  programs.home-manager.enable = true;

  # Linux/WSL2向けパッケージ
  home.packages = with pkgs; [
    git
    gpg
    ugrep
    zsh
    # go はmiseで管理するため不要
  ];
}
