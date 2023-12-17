{ fetchtorrent, runCommand, dosbox-x, xvfb-run, x11vnc, tesseract, expect, vncdo
, writeScript, writeShellScript, writeText, fetchFromGitHub, makeWin2kImage
, callPackage }:
{ dosPostInstall ? "", ... }:
let
  win2k = makeWin2kImage { };
  winxp-installer = fetchtorrent {
    url =
      "https://archive.org/download/WinXPProSP3x86/WinXPProSP3x86_archive.torrent";
    hash = "sha256-NDCPO4gT4rgfB76HrF/HtaRNzSfpXJUSHbqLqECvkpU=";
  };
  dosboxConf = writeText "dosbox.conf" ''
    [dosbox]
    memsize = 64

    [cpu]
    cputype = pentium

    [autoexec]
    imgmount C win2k.img
    imgmount D winxp.iso
    boot -l C
  '';
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
        echo OCR "$NEW_TEXT"
        TEXT="$NEW_TEXT"
      fi
    done
  '';
  expectScript = let
    vncdoWrapper = writeScript "vncdoWrapper" ''
      sleep 3
      ${vncdo}/bin/vncdo --force-caps -s 127.0.0.1::5900 "$@"
    '';
  in writeScript "expect.sh" ''
    #!${expect}/bin/expect -f
    set debug 5
    set timeout -1
    spawn ${tesseractScript}
    expect "Log 0n to Windows"
    exec ${vncdoWrapper} key enter
    expect "Getting started with"
    exec ${vncdoWrapper} pause 3 key alt-f4 pause 3 key ctrl-esc pause 3 key r pause 3 type cmd.exe key enter
    expect "<C> Copyright 1985-1999 Microsoft Corp"
    exec ${vncdoWrapper} type "d:" key enter type "setup" key enter
    expect "Welcome to Microsoft Windows XP"
    exec ${vncdoWrapper} key i
    expect "Welcome to Windows Setup"
    exec ${vncdoWrapper} key enter
    expect "License Agreement"
    exec ${vncdoWrapper} key tab key enter
    expect "Your Product Key"
    exec ${vncdoWrapper} type mrx3f type 47b9t type 2487j type kwkmf type rpwby key enter
    expect "Get Updated Setup Files"
    exec ${vncdoWrapper} key down key enter
    expect "TODO"
    exec ${vncdoWrapper} TODO
    expect "TODO"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    exit 0
  '';
  installedImage = runCommand "winxp.img" {
    # set __impure = true; for debugging
    __impure = true;
    buildInputs = [ dosbox-x xvfb-run x11vnc ];
    passthru = rec {
      makeRunScript = callPackage ./run.nix;
      runScript = makeRunScript { };
    };
  } ''
    echo "winxp-installer src: ${winxp-installer}"
    cp --no-preserve=mode ${winxp-installer}/*.iso winxp.iso
    cp --no-preserve=mode ${win2k} win2k.img
    runDosboxVnc() {
      xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" dosbox-x -conf ${dosboxConf} || true &
      dosboxPID=$!
      DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 &
    }
    ${expectScript} &
    expectScriptPID=$!
    for stage in $(seq 100); do
      echo STAGE $stage
      runDosboxVnc
      wait $dosboxPID
    done
    wait $expectScriptPID
    cp win2k.img $out
  '';
  postInstalledImage = let
    dosboxConf-postInstall = writeText "dosbox.conf" ''
      [cpu]
      turbo=on
      stop turbo on key = false

      [autoexec]
      imgmount C winxp.img
      ${dosPostInstall}
      exit
    '';
  in runCommand "winxp.img" {
    buildInputs = [ dosbox-x ];
    inherit (installedImage) passthru;
  } ''
    cp --no-preserve=mode ${installedImage} ./winxp.img
    SDL_VIDEODRIVER=dummy dosbox-x -conf ${dosboxConf-postInstall}
    mv winxp.img $out
  '';
in if (dosPostInstall != "") then postInstalledImage else installedImage
