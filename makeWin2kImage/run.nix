{ writeShellScriptBin, writeText, lib, dosbox-x, makeWin2kImage
, extraDosboxFlags ? [ ], diskImage ? makeWin2kImage {
  dosPostInstall = ''
    c:
    echo win >> AUTOEXEC.BAT
  '';
} }:
let
  dosboxConf = writeText "dosbox.conf" ''
    [dosbox]
    memsize = 32

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

  if [ ! -f win2k.img ]; then
    echo "win2k.img not found, making disk image ./win2k.img"
    cp --no-preserve=mode ${diskImage} ./win2k.img
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

