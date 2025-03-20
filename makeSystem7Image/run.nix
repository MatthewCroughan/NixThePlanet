{ writeShellScriptBin
, minivmac
, fetchtorrent
, makeSystem7Image
, extraMinivmacFlags ? []
, runCommand
, unzip
, lib
}:
let
  roms = fetchtorrent {
    url = "https://archive.org/download/Macintosh_ROMs_Collection_1990s/Macintosh_ROMs_Collection_1990s_archive.torrent";
    hash = "sha256-YO1HfoCf57bQlred9aGyxBH17PlZIcsCYItTiE2r3D4=";
  };
  vmac-rom = runCommand "vMac.rom" {
    nativeBuildInputs = [ unzip ];
  } ''
    cp ${roms}/Mac_ROMs.zip ./roms.zip
    unzip -j roms.zip "Mac_ROMs/*4D1F8172*" -d ./rom
    mv ./rom/* ./vMac.ROM
    mv vMac.ROM $out
  '';
  image = makeSystem7Image {};
in
writeShellScriptBin "run-system7.sh" ''
  set -x
  cd $(mktemp -d)
  cp ${vmac-rom} ./vMac.ROM
  ${minivmac}/bin/minivmac ${image} ${lib.concatStringsSep " " extraMinivmacFlags} "''${args[@]}"
''
