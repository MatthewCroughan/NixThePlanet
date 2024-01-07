# The installer from DOS (winnt.exe) doesn't work, so use winnt32.exe from Windows 2000

{ lib, fetchtorrent, runCommand, dosbox-x, xvfb-run, x11vnc, vncdo, tesseract
, expect, writeText, writeShellScript, writeScript, makeWin2kImage, callPackage
}:
{ dosPostInstall ? "", answerFile ?
  writeText "answers.ini" (lib.generators.toINI { } (import ./answers.nix)) }:
let
  win2k = makeWin2kImage { imageType = "hd_2gig"; };
  winxp-installer = fetchtorrent {
    url =
      "https://archive.org/download/WinXPProSP3x86/WinXPProSP3x86_archive.torrent";
    hash = "sha256-NDCPO4gT4rgfB76HrF/HtaRNzSfpXJUSHbqLqECvkpU=";
  };
  dosboxConf = stage:
    writeText "dosbox.conf" ''
      [dosbox]
      memsize = 128

      [dos]
      ver = 7.0  # Need long filenames support to edit the C drive in autoexec
      hard drive data rate limit = 0
      floppy drive data rate limit = 0

      [cpu]
      cputype = ppro_slow
      # Turbo breaks win2k boot so disable during the win2k boostrap
      # TODO: turbo = ${if stage == 1 then "off" else "on"}

      [autoexec]
      imgmount c win2k.img
      imgmount d winxp.iso
      ${lib.optionalString (stage == 2) ''
        # After the XP install is bootstrapped, remove the old Windows 2000 files to make space for XP
        deltree /y c:\WINDOWS
        deltree /y "c:\Documents and Settings"
        deltree /y "c:\Program Files"
      ''}
      boot -l c
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
  in writeScript "expect.sh" ''
    #!${expect}/bin/expect -f
    set debug 5
    set timeout -1
    spawn ${tesseractScript}
    expect "ENTER-Install"
    exec ${vncdoWrapper} key enter
    # Keep running until killed so the entire build gets tesseract log output
    while { 1 } { sleep 10000 }
  '';
  installedImage = runCommand "winxp.img" {
    # set __impure = true; for debugging
    # __impure = true;
    buildInputs = [ dosbox-x xvfb-run x11vnc ];
    passthru = rec {
      makeRunScript = callPackage ./run.nix;
      runScript = makeRunScript { };
    };
  } ''
    ln -s ${winxp-installer}/*.iso winxp.iso
    cp --no-preserve=mode ${win2k} win2k.img
    cp --no-preserve=mode ${answerFile} answers.ini
    # Copy answer file to win2k.img and add autostart script that runs the XP installer
    (
      SDL_VIDEODRIVER=dummy dosbox-x -conf ${
        writeText "dosbox.conf" ''
          [dos]
          ver = 7.0  # Need long filenames support to edit the C drive in autoexec

          [autoexec]
          mount a .
          imgmount c win2k.img
          copy a:\answers.ini c:\
          echo d:\i386\winnt32.exe /unattend:c:\answers.ini > "c:\Documents and Settings\All Users\Start Menu\Programs\Startup\start-xp-install.bat"
          exit
        ''
      }
    )
    (
      while true; do
        DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 || true
        echo RESTARTING VNC
      done
    ) &
    ${expectScript} &
    ${lib.strings.concatMapStrings (stage: ''
      echo STAGE ${toString stage}
      xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" \
        dosbox-x -conf ${dosboxConf stage} || true
    '') (lib.range 1 3)}
    mkdir $out
    cp win2k.img $out
  '';
  postInstalledImage = let
    dosboxConf-postInstall = writeText "dosbox.conf" ''
      [cpu]
      turbo = on
      stop turbo on key = false

      [autoexec]
      imgmount c winxp.img
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
