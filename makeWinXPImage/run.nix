{ writeShellScriptBin, writeText, lib, dosbox-x, makeWinXPImage
, extraDosboxFlags ? [ ], diskImage ? makeWinXPImage { } }:
let
  dosboxConf = writeText "dosbox.conf" ''
    [dosbox]
    memsize = 128

    [cpu]
    cputype = ppro_slow

    [sdl]
    autolock = true

    [autoexec]
    imgmount C winxp.img
    boot -l C
  '';
in writeShellScriptBin "run-winxp.sh" ''
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

