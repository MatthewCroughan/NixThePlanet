# TODO: Maybe we can make an automated software installer since the
# customize/install buttons are always at the same coordinates on the screen
{ runCommand
, callPackage
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
, makeBlankHfsDisk
, fetchFromGitHub
, fetchtorrent
, fetchzip
, fetchurl
, buildPackages
, stdenv
, lib
}:
{ ... }:
let
  roms = fetchtorrent {
    url = "https://archive.org/download/Macintosh_ROMs_Collection_1990s/Macintosh_ROMs_Collection_1990s_archive.torrent";
    hash = "sha256-YO1HfoCf57bQlred9aGyxBH17PlZIcsCYItTiE2r3D4=";
  };

  nsi = fetchurl {
    urls = [
      "https://archive.org/download/Macintosh_Garden_Applications_2021_N/NSI_1.4.5.img_.7z"
    ];
    hash = "sha256-cduVIWQanABWx4MTtDzXppmkfdaeSoWVdmXsW+Yqar0=";
  };

  system67z = fetchurl {
    urls = [
      "https://winworldpc.com/download/42f25102-d7aa-11e7-a73f-fa163e9022f0/from/c39ac2af-c381-c2bf-1b25-11c3a4e284a2"
      "https://winworldpc.com/download/42f25102-d7aa-11e7-a73f-fa163e9022f0/from/c3ae6ee2-8099-713d-3411-c3a6e280947e"
    ];
    hash = "sha256-N/YNH6I8b96aLN06VczTAIAddM/ExEoGUpRktdk+n08=";
  };

  tesseractScript = writeShellScript "tesseractScript" ''
    export OMP_THREAD_LIMIT=1
    cd $(mktemp -d)
    TEXT=""
    while true
    do
      sleep 3
      ${vncdo}/bin/vncdo --delay=1000 -s 127.0.0.1::5900 capture cap.png
      NEW_TEXT="$(${tesseract}/bin/tesseract cap.png stdout 2>/dev/null)"
      if [ "$TEXT" != "$NEW_TEXT" ]; then
        echo "$NEW_TEXT"
        TEXT="$NEW_TEXT"
      fi
    done
  '';

  system6Installed-stage1 = let
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
      expect "Special"
      exec ${vncdoWrapper} key alt-w
      exec ${vncdoWrapper} move 620 180 click 2 key alt-o
      expect "System Startu"
      exec ${vncdoWrapper} move 330 230 click 2 sleep 3 key alt-o sleep 3 key enter
      expect "Click Install to place"
      exec ${vncdoWrapper} move 550 420 click 2 sleep 3 key enter
      expect "shift-click to select multiple"
      exec ${vncdoWrapper} keydown shift move 220 225 click 2 move 220 235 click 2 move 220 245 click 2 move 220 265 click 2 key enter keyup shift
      expect "Quit to leave the Installer"
      exec ${vncdoWrapper} key enter
      expect "System Startu"
      exec ${vncdoWrapper} key alt-w
      expect "Special"
      exec ${vncdoWrapper} move 620 300 click 2 key alt-o
      expect "Networt Sortears st"
      exec ${vncdoWrapper} move 250 220 click 2 key alt-o
      expect "Welcome to the Network Software Installer"
      exec ${vncdoWrapper} sleep 6 key enter sleep 3 key tab sleep 3 move 550 420 click 2 sleep 3 move 220 220 click 2 sleep 3 key enter
      expect "successful"
      exec ${vncdoWrapper} key enter
      expect "Special"
      exec ${vncdoWrapper} move 330 140 mousedown 1 sleep 3 move 330 260 sleep 3 mouseup 1
      expect "¥ou may now switch off your Macintosh safely."
      exec ${vncdoWrapper} key ctrl-q
      exit 0
    '';
    script = writeScript "" ''
      cp --no-preserve=mode ${makeBlankHfsDisk {}} ./blankdisk.img
      minivmac system6/*/*Startup* ./blankdisk.img system6/*/*Additions* nsi/*.img
    '';
  in
  runCommand "system6.img" { buildInputs = [ p7zip unzip minivmac xvfb-run x11vnc ];
    # set __impure = true; for debugging
    # __impure = true;
    passthru = {
      runScript = callPackage ./run.nix {};
    };
   } ''
    cp ${roms}/Mac_ROMs.zip ./roms.zip
    cp ${system67z} ./system6.7z
    cp ${nsi} ./nsi.7z
    unzip -j roms.zip "Mac_ROMs/*4D1F8172*" -d ./rom
    mv ./rom/* ./vMac.ROM
    7z x system6.7z -osystem6
    7z x nsi.7z -onsi

    xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" ${script} &
    minivmacPID=$!
    DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 &
    ${expectScript} &
    wait $!
    cp ./blankdisk.img $out
  '';
in system6Installed-stage1
