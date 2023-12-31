{ lib, fetchurl, runCommand, p7zip, dosbox-x, xvfb-run, x11vnc, imagemagick
, tesseract, expect, vncdo, writeScript, writeShellScript, writeText
, makeWin98Image, callPackage }:
{ dosPostInstall ? "", answerFile ? writeText "answers.ini"
  (lib.generators.toINI { } {
    Data = {
      AutoPartition = 1;
      MsDosInitiated = "0";
      UnattendedInstall = "Yes";
    };
    Unattended = {
      UnattendMode = "FullUnattended";
      OemSkipEula = "Yes";
      OemPreinstall = "No";
      TargetPath = "WINDOWS";
    };
    GuiUnattended = {
      AdminPassword = "*";
      AutoLogon = "Yes";
      OEMSkipRegional = 1;
      TimeZone = 4;
      OemSkipWelcome = 1;
    };
    UserData = {
      FullName = "user";
      OrgName = "NixThePlanet";
      ComputerName = "*";
      ProductID = "RBDC9-VTRC8-D7972-J97JY-PRVMG";
    };
    RegionalSettings.LanguageGroup = 1;
    Identification.JoinWorkgroup = "WORKGROUP";
    Networking.InstallDefaultComponents = "Yes";
  }) }:
let
  win2k-installer = fetchurl {
    name = "win2k.7z";
    urls = [
      "https://winworldpc.com/download/413638c2-8d18-c39a-11c3-a4e284a2c3a5/from/c39ac2af-c381-c2bf-1b25-11c3a4e284a2"
      "https://winworldpc.com/download/413638c2-8d18-c39a-11c3-a4e284a2c3a5/from/c3ae6ee2-8099-713d-3411-c3a6e280947e"
      "https://cloudflare-ipfs.com/ipfs/QmT7rGKU4WzQxwpfZqFgGwGSCrBbBm7SejUSPgDzxAgPye/Microsoft%20Windows%202000%20Professional%20(5.00.2195).7z"
    ];
    sha512 =
      "9cb026d8eaa3933d7ca0447c7e1b05fd1504a6063b16a86d5cca4dc04ef5d598bd8ae95dac6f10671422ece192b1aff94ecd505d2cd7a15981eaa4fd691f1489";
  };
  dosboxConf = writeText "dosbox.conf" ''
    [dosbox]
    memsize = 32

    [cpu]
    turbo=on
    stop turbo on key = false

    [autoexec]
    mount a .
    if not exist a:\win2k.img imgmake win2k.img -t hd_1gig
    imgmount c win2k.img -t hdd
    imgmount d win2k.iso
    c:
    if not exist c:\windows d:\i386\winnt /s:d:\ /u:a:\answers.ini
    boot -l c
  '';
  iso = runCommand "win2k.iso" { } ''
    echo "win2k-installer src: ${win2k-installer}"
    mkdir win2k
    ${p7zip}/bin/7z x -owin2k ${win2k-installer}
    ls -lah win2k
    mv win2k/*/*.iso $out
  '';
  installedImage = runCommand "win2k.img" {
    passthru = rec {
      makeRunScript = callPackage ./run.nix;
      runScript = makeRunScript { };
    };
  } ''
    echo "iso src: ${iso}"
    cp --no-preserve=mode ${iso} win2k.iso
    cp --no-preserve=mode ${answerFile} answers.ini
    for stage in $(seq 100); do
      echo STAGE $stage
      ${lib.meta.getExe dosbox-x} -conf ${dosboxConf}
    done
    cp win2k.img $out
  '';
  postInstalledImage = let
    dosboxConf-postInstall = writeText "dosbox.conf" ''
      [dosbox]
      memsize = 32

      [cpu]
      turbo=on
      stop turbo on key = false

      [autoexec]
      imgmount c win2k.img
      ${dosPostInstall}
      exit
    '';
  in runCommand "win2k.img" { inherit (installedImage) passthru; } ''
    cp --no-preserve=mode ${installedImage} ./win2k.img
    SDL_VIDEODRIVER=dummy ${
      lib.meta.getExe dosbox-x
    } -conf ${dosboxConf-postInstall}
    mv win2k.img $out
  '';
in if (dosPostInstall != "") then postInstalledImage else installedImage
