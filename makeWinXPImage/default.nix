{ lib, fetchtorrent, runCommand, dosbox-x, xvfb-run, x11vnc, writeText
, makeWin2kImage, callPackage }:
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
    memsize = 64

    [dos]
    ver = 7.0  # Need long filenames support to edit the C drive in autoexec

    [cpu]
    cputype = pentium

    [autoexec]
    imgmount c win2k.img
    imgmount d winxp.iso
    boot -l c
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
    cp --no-preserve=mode ${answerFile} answers.ini
    SDL_VIDEODRIVER=dummy dosbox-x -nopromptfolder -hostrun \
      -c 'imgmount c win2k.img' \
      -c 'mount a .' \
      -c 'xcopy a:/answers.ini c:/' \
      -c 'echo d:\\i386\\winnt32.exe /unattend:c:\\answers.ini > "c:/Documents and Settings/All Users/Start Menu/Programs/Startup/start-xp-install.bat"' \
      -c 'exit'
    false
    rm -f answers.ini
    (
      while true; do
        DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 || true
        echo RESTARTING VNC
      done
    ) &
    for stage in $(seq 100); do
      echo STAGE $stage
      xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" dosbox-x -conf ${dosboxConf} || true
    done
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
