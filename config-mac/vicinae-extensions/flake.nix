{
  # Vicinae で使う Raycast 拡張を Nix でビルドする。
  # 配置は `mise run bootstrap:vicinae-extensions`（tasks/bootstrap.toml）が行う。
  description = "Raycast extensions for Vicinae";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # mkRayCastExtension.nix だけ使うのでソースとして取り込む（vicinae 本体の依存を lock に入れない）
    vicinae = {
      url = "github:vicinaehq/vicinae";
      flake = false;
    };
  };

  outputs = {
    nixpkgs,
    vicinae,
    ...
  }: let
    inherit (nixpkgs) lib;

    # raycast/extensions のコミット。拡張を更新するときはこれと各 hash を上げる
    rev = "d0885a5383fc1ae78217092f311518dc2cdcca48";

    # raycast/extensions/extensions/<name> のフォルダ名 = ストアの拡張名 → sparse checkout の hash
    extensions = {
      apple-notes = "sha256-tGewSHAxSUVbYAfPdSMwoDoIUqfaff2jS82pXXMmb04=";
      arc = "sha256-NqAWcud/EF4kHxsTbQi3djlyGD7VnG8zpbMTbpeU/Lo=";
      github = "sha256-20lWrpSi3MD3E1EelAybRS9jB2UsXp5wvKaYTfTXZoI=";
      google-meet = "sha256-G/0mOjC1GS4J4dkgOtBufRIHyP2s0hBz2q3EsIQJ3aU=";
      miniflux = "sha256-FJyC5XNYI9JUFCSicMnwpCRRg7/vs7BVQre2XBJGwPw=";
      obsidian = "sha256-UsWg/AOdQdiBNzJUTMmgrI1bW77ebbOJF++MZYw/8/Q=";
      port-manager = "sha256-OKr8SuyVJliSW8uwFsPc2wqUFVF34NpvOhadcbuAUuE=";
      raindrop-io = "sha256-H1UMCNRcdmbXsHsDO3Up2E63CA9k9dL0yWuOIJ+ZAp4=";
      thock = "sha256-tK+IwJ4oFBjMsEczLZzM7aibR02L3zW3nvxv1x6D3Bg=";
    };

    systems = ["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"];
  in {
    packages = lib.genAttrs systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      mkRayCastExtension = pkgs.callPackage "${vicinae}/nix/mkRayCastExtension.nix" {};
      # `ray build` は成功後に Raycast を開こうとして xdg-open/open を呼び、無いとビルドごと落ちる。
      # macOS でも本物の open が走らないよう、何もしないスタブを PATH の先頭に置く
      noOpen = pkgs.symlinkJoin {
        name = "no-open";
        paths = map (bin: pkgs.writeShellScriptBin bin "exit 0") ["open" "xdg-open"];
      };
      built = lib.mapAttrs (name: hash:
        mkRayCastExtension {
          inherit name rev hash;
          nativeBuildInputs = [noOpen];
        })
      extensions;
    in
      built
      // {
        # ストアから入れたときと同じ ID（ディレクトリ名 store.raycast.<name>）で並べる。
        # ID が同じなので settings.json の providers（"@author/store.raycast.<name>"）をそのまま使える
        default = pkgs.linkFarm "vicinae-raycast-extensions" (
          lib.mapAttrsToList (name: drv: {
            name = "store.raycast.${name}";
            path = drv;
          })
          built
        );
      });
  };
}
