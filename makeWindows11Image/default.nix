{ wfvm, fetchtorrent, callPackage }:
{ ... }@args: (wfvm.lib.makeWindowsImage {
#  pkgs = import wfvm.inputs.nixpkgs.legacyPackages.x86_64-linux.pkgs.path {
#    system = "x86_64-linux";
#    overlays = [
#      (self: super: {
#        libguestfs-appliance = super.libguestfs-appliance.overrideAttrs {
#          src = super.fetchurl {
#            url = "https://web.archive.org/web/20230826201338if_/https://download.libguestfs.org/binaries/appliance/appliance-1.40.1.tar.xz";
#            hash = "sha256-Gq8L7xhRS46evQxhMO1RiLb2pwUuSJHV82IAePSFY+Y=";
#          };
#        };
#      })
#    ];
#  };
  windowsImage = (fetchtorrent {
    backend = "rqbit";
    url = "magnet:?xt=urn:btih:86ABFFEFB9F9EE886A566CB9DA7929120727D0C9";
    hash = "sha256-CqpeDm2x8ptgd4Zy4C5B+ZjmskzlGa0s/aLbZVBUn5E=";
  }) + "/*.iso";
} // args).overrideAttrs (_: { passthru.runScript = callPackage ./run.nix {}; })
