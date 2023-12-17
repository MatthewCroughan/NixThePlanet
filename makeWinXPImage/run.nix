{ writeShellScriptBin, writeText, lib, dosbox-x, makeWinXPImage
, extraDosboxFlags ? [ ], diskImage ? makeWinXPImage {
  dosPostInstall = ''
    c:
    echo win >> AUTOEXEC.BAT
  '';
} }:
let
  dosboxConf = writeText "dosbox.conf" ''
    [sdl]
    autolock = true

    [autoexec]
    imgmount C win2k.img
    boot -l C
  '';
in writeShellScriptBin "run-win2k.sh" ''
  args=(
    -conf ${dosboxConf}
    ${lib.concatStringsSep " " extraDosboxFlags}
    "$@"
  )

  if [ ! -f winxp.img ]; then
    echo "winxp.img not found, making disk image ./winxp.img"
    cp --no-preserve=mode ${diskImage} ./winxp.img
  fi

  run_dosbox() {
    ${dosbox-x}/bin/dosbox-x "''${args[@]}"
  }

  run_dosbox

  if [ $? -ne 0 ]; then
    echo "Dosbox crashed. Re-running with SDL_VIDEODRIVER=x11."
    SDL_VIDEODRIVER=x11 run_dosbox
  fi
''

