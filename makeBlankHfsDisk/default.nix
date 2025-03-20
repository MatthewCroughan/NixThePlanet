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
, fetchFromGitHub
, fetchtorrent
, fetchzip
, fetchurl
, buildPackages
, stdenv
, lib
}:
{ diskSizeBytes ? 500000000, # 500M
  ...
}:
let
  diskSize = if diskSizeBytes > 2000000000 then throw "diskSizeBytes ${toString diskSizeBytes} is greater than 2G, which is larger than Macintosh System 6 or 7 support" else diskSizeBytes;
  roms = fetchtorrent {
    url = "https://archive.org/download/Macintosh_ROMs_Collection_1990s/Macintosh_ROMs_Collection_1990s_archive.torrent";
    hash = "sha256-YO1HfoCf57bQlred9aGyxBH17PlZIcsCYItTiE2r3D4=";
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
      ${vncdo}/bin/vncdo -s 127.0.0.1::5900 capture cap.png
      NEW_TEXT="$(${tesseract}/bin/tesseract cap.png stdout 2>/dev/null)"
      if [ "$TEXT" != "$NEW_TEXT" ]; then
        echo "$NEW_TEXT"
        TEXT="$NEW_TEXT"
      fi
    done
    '';

  blankHfsDisk = let
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
      expect "HFS par"
      exec ${vncdoWrapper} type "c"
      expect "initialize"
      exec ${vncdoWrapper} move 490 290 click 2
      expect "erase all"
      exec ${vncdoWrapper} move 490 290 click 2
      expect "untitied"
      exec ${vncdoWrapper} type "Macintosh HD" pause 3 key enter
      expect "Special"
      exec ${vncdoWrapper} move 330 140 mousedown 1 sleep 3 move 330 260 sleep 3 mouseup 1
      expect "¥ou may now switch off your Macintosh safely."
      exec ${vncdoWrapper} key ctrl-q
      exit 0
    '';
    script = writeScript "" ''
      minivmac system6/*/*Startup* blankdisk.img
    '';
  in
  runCommand "blankdisk.img" { buildInputs = [ p7zip unzip minivmac xvfb-run x11vnc ];
    # set __impure = true; for debugging
   } ''
    dd if=/dev/zero of=blankdisk.img bs=${toString diskSize} count=1
    cp ${roms}/Mac_ROMs.zip ./roms.zip
    cp ${system67z} ./system6.7z
    unzip -j roms.zip "Mac_ROMs/*4D1F8172*" -d ./rom
    mv ./rom/* ./vMac.ROM
    7z x system6.7z -osystem6

    xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" ${script} &
    minivmacPID=$!
    DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 &
    ${expectScript} &
    wait $!
    cp ./blankdisk.img $out
    '';
in blankHfsDisk
