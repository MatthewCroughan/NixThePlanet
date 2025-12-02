# WARNING: You should use `builtins.getFlake` instead of this where possible. This file will go away when nix's flakes feature becomes stable.
(import
  (
    fetchTarball {
      url = "https://github.com/nix-community/flake-compat/archive/38fd3954cf65ce6faf3d0d45cd26059e059f07ea.tar.gz";
      sha256 = "sha256-FrlieJH50AuvagamEvWMIE6D2OAnERuDboFDYAED/dE=";
    }
  )
  { src = ./.; }).defaultNix
