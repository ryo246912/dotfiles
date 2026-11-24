```sh
% nix

# exec nix-shell [--run cmd:executes the command in a non-interactive shell][-p:setup package shell]
nix-shell --run zsh -p <package>

# exec nix-shell(experimental)
nix shell nixpkgs#<package>

# search package [https://search.nixos.org/packages]
nix search nixpkgs "^<package>$"

# apply flake.nix
nix run nix-darwin -- switch --flake .

# garbage collection
nix store gc
```

$ xxx: echo xxx
;$
