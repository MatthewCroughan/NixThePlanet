# Fabulous.systems demonstrated that installing Windows 2000 in DOSBox-X is possible in
# https://fabulous.systems/posts/2023/07/installing-windows-2000-in-dosbox-x/
# but this package uses a different approach, installing from scratch instead of
# from Windows 98 and using an answer file for unattended installation.

{ lib, fetchurl, runCommand, p7zip, dosbox-x, writeText, callPackage }:
{ dosPostInstall ? "", answerFile ?
  writeText "answers.ini" (lib.generators.toINI { } (import ./answers.nix)) }:
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
    turbo = off  # Turbo prevents the boot screen from progressing

    [autoexec]
    mount a .
    if not exist a:\win2k.img imgmake win2k.img -t hd_1gig
    imgmount c win2k.img -t hdd
    imgmount d win2k.iso
    c:
    if not exist c:\ntldr d:\i386\winnt /s:d:\ /u:a:\answers.ini
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
    for stage in 1 2; do
      echo STAGE $stage
      SDL_VIDEODRIVER=dummy ${lib.getExe dosbox-x} -conf ${dosboxConf} || true
    done
    cp win2k.img $out
  '';
  postInstalledImage = let
    dosboxConf-postInstall = writeText "dosbox.conf" ''
      [dosbox]
      memsize = 32

      [autoexec]
      imgmount c win2k.img
      ${dosPostInstall}
      exit
    '';
  in runCommand "win2k.img" { inherit (installedImage) passthru; } ''
    cp --no-preserve=mode ${installedImage} ./win2k.img
    SDL_VIDEODRIVER=dummy ${lib.getExe dosbox-x} -conf ${dosboxConf-postInstall}
    mv win2k.img $out
  '';
in if (dosPostInstall != "") then postInstalledImage else installedImage
