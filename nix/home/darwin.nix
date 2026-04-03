{ pkgs, ... }:
{
  home = {
    username = "ryo.";
    homeDirectory = "/Users/ryo.";
    stateVersion = "24.11";
  };

  # home-managerが自身を管理できるようにする
  programs.home-manager.enable = true;
}
