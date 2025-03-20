{ runCommand
, unzip
, p7zip
, minivmac
, xvfb-run
, x11vnc
, tesseract
, expect
, vncdo
, writeScript
, writeShellScript
, writeText
, makeMsDos622Image
, fetchFromGitHub
, fetchtorrent
, fetchzip
, fetchurl
, callPackage
, makeBlankHfsDisk
}:
{ ... }:
let

#  djjr = ((import <nixpkgs> {}).callPackage ./djjr.nix {});
#  blankdisk = runCommand "blankdisk-djjr.img" { nativeBuildInputs = [ djjr ]; } ''
#    djjr create mac-device-partitioned --list-premade $out -sM 500
#  '';

  blankdisk = makeBlankHfsDisk {};

  roms = fetchtorrent {
    url = "https://archive.org/download/Macintosh_ROMs_Collection_1990s/Macintosh_ROMs_Collection_1990s_archive.torrent";
    hash = "sha256-YO1HfoCf57bQlred9aGyxBH17PlZIcsCYItTiE2r3D4=";
  };

  # System 7.5.3
  # Slightly different install flow
  #system7 = fetchurl {
  #  url = "https://archive.org/download/Macintosh_System_7.5_Version_7.5.3_Apple_Computer_U96073-016A_Version_1.0_CD_199/Macintosh%20System%207.5%20Version%207.5.3%20%28Apple%20Computer%29%28U96073-016A%29%28Version%201.0%20CD%29%281996%29.iso";
  #  hash = "sha256-t5ABWdX1V6fRhkMbJdeWzgJ3WYYTlYialvB9SPLw180=";
  #};

  #system7 = ./sys7.7z;

  system7 = fetchurl {
    name = "system7.7z";
    urls = [
      "https://winworldpc.com/download/70c2bcc2-ad48-c3ab-7511-c3a6c2bb2a52/from/c39ac2af-c381-c2bf-1b25-11c3a4e284a2"
      "https://winworldpc.com/download/70c2bcc2-ad48-c3ab-7511-c3a6c2bb2a52/from/c3ae6ee2-8099-713d-3411-c3a6e280947e"
    ];
    hash = "sha256-sORHLNyxLeLKGckYRWstTzFJ+ULIj+bxcUljlOxDhPs=";
  };

  tesseractScript = writeShellScript "tesseractScript" ''
    export OMP_THREAD_LIMIT=1
    cd $(mktemp -d)
    TEXT=""
    while true
    do
      sleep 3
      ${vncdo}/bin/vncdo -s 127.0.0.1::5900 capture cap.png
      NEW_TEXT="$(${tesseract}/bin/tesseract --dpi 30 --psm 11 cap.png stdout 2>/dev/null)"
      if [ "$TEXT" != "$NEW_TEXT" ]; then
        echo "$NEW_TEXT"
        TEXT="$NEW_TEXT"
      fi
    done
  '';

  expectScript = let
    vncdoWrapper = writeScript "vncdoWrapper" ''
      sleep 3
      ${vncdo}/bin/vncdo --force-caps -s 127.0.0.1::5900 "$@"
    '';
  in writeScript "expect.sh"
  ''
    #!${expect}/bin/expect -f
    set debug 5
    set timeout -1
    spawn ${tesseractScript}
    expect "Welcome to the Apple Installer"
    exec ${vncdoWrapper} key enter
    expect "Click Install"
    exec ${vncdoWrapper} key enter
    expect "Installation on"
    exec ${vncdoWrapper} key enter
    expect "switch off"
    exec ${vncdoWrapper} key ctrl-q
    exit 0
  '';

  script = writeScript "minivmac-wrapper" ''
    set -x
    minivmac system7/*/{Install.img,Install\ 2.img,Tidbits.img,Printing.img,Fonts.img} blankdisk.img
  '';
in
runCommand "system7.img" { buildInputs = [ p7zip unzip minivmac xvfb-run x11vnc ];
  # set __impure = true; for debugging
  # __impure = true;
  passthru.runScript = callPackage ./run.nix {};
 } ''
  cp ${blankdisk} ./blankdisk.img
  chmod +w blankdisk.img
  cp ${roms}/Mac_ROMs.zip ./roms.zip
  cp ${system7} ./system7.7z
  unzip -j roms.zip "Mac_ROMs/*4D1F8172*" -d ./rom
  mv ./rom/* ./vMac.ROM
  find
  file ./vMac.ROM
  ls ./vMac.ROM
  7z x system7.7z -osystem7
  echo HELLO
  ls -lah system7/*
  echo HELLO

  xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" ${script} &
  minivmacPID=$!
  DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 &
  ${expectScript} &
  wait $!
  cp ./blankdisk.img $out
''
