# The installer from DOS (winnt.exe) doesn't work, so use winnt32.exe from Windows 2000

{ lib, fetchtorrent, runCommand, p7zip, cdrkit, dosbox-x, xvfb-run, x11vnc
, writeText, makeWin2kImage, callPackage }:
{ dosPostInstall ? "", answerFile ?
  writeText "answers.ini" (lib.generators.toINI { } (import ./answers.nix)) }:
let
  win2k = makeWin2kImage { };
  winxp-installer = fetchtorrent {
    url =
      "https://archive.org/download/WinXPProSP3x86/WinXPProSP3x86_archive.torrent";
    hash = "sha256-NDCPO4gT4rgfB76HrF/HtaRNzSfpXJUSHbqLqECvkpU=";
  };
  dosboxConf = writeText "dosbox.conf" ''
    [dosbox]
    memsize = 128
    machine = svga_s3trio64v+

    [dos]
    ver = 8.0

    [cpu]
    cputype = ppro_slow

    [serial]
    serial1 = disabled
    serial2 = disabled
    serial3 = disabled
    serial4 = disabled
    serial5 = disabled
    serial6 = disabled
    serial7 = disabled
    serial8 = disabled
    serial9 = disabled

    [parallel]
    parallel1 = disabled
    parallel2 = disabled
    parallel3 = disabled
    parallel4 = disabled
    parallel5 = disabled
    parallel6 = disabled
    parallel7 = disabled
    parallel8 = disabled
    parallel9 = disabled
    dongle = false

    [autoexec]
    imgmount c win2k.img
    imgmount d winxp.iso
    boot -l c
  '';
  installedImage = runCommand "winxp.img" {
    # set __impure = true; for debugging
    __impure = true;
    buildInputs = [ p7zip cdrkit dosbox-x xvfb-run x11vnc ];
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
          ver = 8.0  # Need long filenames support to edit the C drive in autoexec

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
    for stage in $(seq 3); do
      echo STAGE $stage
      xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" dosbox-x -conf ${dosboxConf} || true
    done
    mkdir $out
    cp win2k.img $out
  '';
  postInstalledImage = let
    dosboxConf-postInstall = writeText "dosbox.conf" ''
      [cpu]
      turbo = on
      stop turbo on key = false

      [dos]
      ver = 8.0

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
