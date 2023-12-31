# https://fabulous.systems/posts/2023/07/installing-windows-2000-in-dosbox-x/

{ lib, fetchurl, runCommand, p7zip, dosbox-x, xvfb-run, x11vnc, imagemagick
, tesseract, expect, vncdo, writeScript, writeShellScript, writeText
, makeWin98Image, callPackage }:
{ dosPostInstall ? "",
# NTFS not supported in dosbox-x, image builds with it probably won't work
useNTFS ? false, ... }:
let
  win98 = makeWin98Image { };
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

    [autoexec]
    imgmount c win2k.img
    imgmount d win2k.iso
    boot -l c
  '';
  tesseractScript = writeShellScript "tesseractScript" ''
    export OMP_THREAD_LIMIT=1
    cd $(mktemp -d)
    TEXT=""
    while true
    do
      sleep 3
      ${vncdo}/bin/vncdo -s 127.0.0.1::5900 capture cap-small.png
      ${imagemagick}/bin/convert cap-small.png -interpolate Integer -filter point -resize 400% cap.png
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
    expect "Recycle Bin"
    send_user "\n### WIN98 BOOTED ###\n"
    while { 1 } {
      exec sleep 10
      send_user "\n### TRYING TO OPEN WIN2K SETUP ###\n"
      expect {
        "Windows 2000 CD" { break }
        "Prompt" {
          send_user "\n### OPENING WIN2K SETUP ###\n"
          exec ${vncdoWrapper} type d: key enter type setup key enter
        }
        "Type the name of" {
          send_user "\n### OPENING COMMAND.COM ###\n"
          exec ${vncdoWrapper} type com pause 1 type mand.com key enter
        }
        "Programs" {
          send_user "\n### OPENING RUN PROMPT ###\n"
          exec ${vncdoWrapper} key r
        }
        "Internet A" {
          send_user "\n### OPENING START MENU ###\n"
          exec ${vncdoWrapper} key ctrl-esc
        }
      }
    }
    exec ${vncdoWrapper} key enter
    expect "Welcome to the Windows 2000"
    exec ${vncdoWrapper} key down key enter
    expect "License Agreement"
    exec ${vncdoWrapper} key tab key enter
    expect "Your Product Key"
    while { 1 } {
      send_user "\n### ENTERING PRODUCT KEY ###\n"
      exec ${vncdoWrapper} type rbdc9 pause 1 type vtrc8 pause 1 type d7972 pause 1 type j97jy pause 1 type prvmg pause 1 key enter
      expect {
        "Select Special Options" { break }
        "Do Windows 2000 Eetup E4" {
          send_user "\n### RETRYING ENTERING PRODUCT KEY ###\n"
          exec ${vncdoWrapper} key enter
          exec ${vncdoWrapper} key tab key tab key tab key tab
          for {set i 0} {$i < 25} {incr i} {
            exec ${vncdoWrapper} key bsp
          }
        }
      }
    }
    exec ${vncdoWrapper} key enter
    expect "To set up Windows 2000 now, press ENTER."
    exec ${vncdoWrapper} key enter
    expect "The following list shows the existing partitions"
    exec ${vncdoWrapper} key enter

    expect "Provide Upgrade Packs"
    exec ${vncdoWrapper} key enter
    expect "File System"
    ${lib.optionalString useNTFS "exec ${vncdoWrapper} key up"}
    exec ${vncdoWrapper} key enter
    expect "Provide Updated Plug and Play Files"
    exec ${vncdoWrapper} key enter
    expect "Upgrade Report"
    exec ${vncdoWrapper} key enter
    expect "Setup found that"
    exec ${vncdoWrapper} key tab key enter
    expect "Setup now has the"
    exec ${vncdoWrapper} key enter
    send_user "\n### WAITING TO BOOT INTO STAGE 2 ###\n"
    expect "Password Creation"
    exec ${vncdoWrapper} key enter
    expect "It is unsafe"
    exec ${vncdoWrapper} key enter
    expect "Log On to Windows"
    exec ${vncdoWrapper} key enter
    expect "Getting Started with Windows 2000"
    exec ${vncdoWrapper} pause 3 key ctrl-esc pause 3 key u pause 3 key down key down key enter
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    exit 0 '';
  iso = runCommand "win2k.iso" { } ''
    echo "win2k-installer src: ${win2k-installer}"
    mkdir win2k
    ${p7zip}/bin/7z x -owin2k ${win2k-installer}
    ls -lah win2k
    mv win2k/*/*.iso $out
  '';
  installedImage = runCommand "win2k.img" {
    # set __impure = true; for debugging
    # __impure = true;
    buildInputs = [ dosbox-x xvfb-run x11vnc ];
    passthru = rec {
      makeRunScript = callPackage ./run.nix;
      runScript = makeRunScript { };
    };
  } ''
    echo "iso src: ${iso}"
    cp --no-preserve=mode ${iso} win2k.iso
    cp --no-preserve=mode ${win98} win2k.img
    runDosboxVnc() {
      xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" dosbox-x -conf ${dosboxConf} || true &
      dosboxPID=$!
      DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 &
    }
    ${expectScript} &
    expectScriptPID=$!
    for stage in $(seq 4); do
      echo STAGE $stage
      runDosboxVnc
      wait $dosboxPID
    done
    wait $expectScriptPID
    cp win98.img $out
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
  in runCommand "win2k.img" {
    buildInputs = [ dosbox-x ];
    inherit (installedImage) passthru;
  } ''
    cp --no-preserve=mode ${installedImage} ./win2k.img
    SDL_VIDEODRIVER=dummy dosbox-x -conf ${dosboxConf-postInstall}
    mv win2k.img $out
  '';
in if (dosPostInstall != "") then postInstalledImage else installedImage
