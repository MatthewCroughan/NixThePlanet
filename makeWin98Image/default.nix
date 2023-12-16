# https://dosbox-x.com/wiki/Guide%3AInstalling-Windows-98#_installation_method_2

{ fetchurl, runCommand, p7zip, dosbox-x, xvfb-run, x11vnc, tesseract, expect
, vncdo, imagemagick, writeScript, writeShellScript, writeText, fetchFromGitHub
, callPackage }:
{ dosPostInstall ? "", ... }:
let
  win98-installer = fetchurl {
    name = "win98.7z";
    urls = [
      "https://winworldpc.com/download/c3b4c382-3210-e280-9d7b-11c3a4c2ac5a/from/c39ac2af-c381-c2bf-1b25-11c3a4e284a2"
      "https://winworldpc.com/download/c3b4c382-3210-e280-9d7b-11c3a4c2ac5a/from/c3ae6ee2-8099-713d-3411-c3a6e280947e"
      "https://cloudflare-ipfs.com/ipfs/QmTTNMpQALDzioSNdDJyr94rkz5tHoAHCDa155fvHyJb4L/Microsoft%20Windows%2098%20Second%20Edition%20(4.10.2222)%20(Retail%20Full).7z"
    ];
    hash = "sha256-47M3azg2ikc7VlFTEJA7elPGovAtSmhOtZqq8j2TJmU=";
  };
  dosboxConf = writeText "dosbox.conf" ''
    [cpu]
    turbo=on
    stop turbo on key = false
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
      echo VNCDO "$@" >2
      ${vncdo}/bin/vncdo --force-caps -s 127.0.0.1::5900 "$@"
    '';
  in writeScript "expect.sh" ''
    #!${expect}/bin/expect -f
    set debug 5
    set timeout -1
    spawn ${tesseractScript}
    expect "Welcome to DOSBox-X"
    send_user "\n### START SETUP ###\n"
    exec ${vncdoWrapper} type "imgmake win98.img -t hd_520" key enter
    exec ${vncdoWrapper} type "imgmount c win98.img -t hdd -fs fat" key enter
    exec ${vncdoWrapper} type "imgmount d win98.iso" key enter
    exec ${vncdoWrapper} type "xcopy d:\\\win98 c:\\\win98 /i /e" key enter
    expect "copied"
    exec ${vncdoWrapper} type "c:" key enter
    exec ${vncdoWrapper} type "cd \\\win98" key enter
    exec ${vncdoWrapper} type "setup" key enter
    expect "To continue, press ENTER"
    exec ${vncdoWrapper} key enter
    expect "click Continue"
    exec ${vncdoWrapper} key enter
    expect "License Agreement"
    send_user "\n### LICENSE AGREEMENT ###\n"
    exec ${vncdoWrapper} key tab key enter
    expect "Windows Product Key"
    send_user "\n### PRODUCT KEY ###\n"
    exec ${vncdoWrapper} type w7xtc type 2ywfb type k6bpt type gmhmv type b6fdy key enter
    expect "Select Directory"
    expect "other than the default"
    send_user "\n### SELECT INSTALL DIR ###\n"
    exec ${vncdoWrapper} key enter
    expect "Setup Options"
    send_user "\n### SETUP OPTIONS ###\n"
    exec ${vncdoWrapper} key enter
    expect "User Information"
    send_user "\n### USER INFORMATION ###\n"
    exec ${vncdoWrapper} type admin key enter
    expect "Windows Components"
    send_user "\n### WINDOWS COMPONENTS ###\n"
    exec ${vncdoWrapper} key enter
    expect "Identification"
    send_user "\n### IDENTIFICATION ###\n"
    exec ${vncdoWrapper} key enter
    expect "Establishing Your Location"
    send_user "\n### ESTABLISHING YOUR LOCATION ###\n"
    exec ${vncdoWrapper} key enter
    expect "Start Copying Files"
    send_user "\n### START COPYING FILES ###\n"
    exec ${vncdoWrapper} key enter
    expect "Welcome to DOSBox-X"
    send_user "\n### REBOOTING INTO SECOND STAGE ###\n"
    exec ${vncdoWrapper} type "imgmount c win98.img" key enter
    expect "mounted as"
    exec ${vncdoWrapper} type "boot c:" key enter
    expect "Date/Time Properties"
    send_user "\n### DATE/TIME PROPERTIES ###\n"
    exec ${vncdoWrapper} key enter
    expect "Welcome to DOSBox-X"
    send_user "\n### REBOOTING INTO THIRD STAGE ###\n"
    exec ${vncdoWrapper} type "imgmount c win98.img" key enter
    expect "mounted as"
    exec ${vncdoWrapper} type "boot c:" key enter
    expect "Enter Windows Password"
    send_user "\n### ENTER WINDOWS PASSWORD ###\n"
    exec ${vncdoWrapper} key enter
    expect "Welcome to Windows"
    send_user "\n### OPENING START MENU ###\n"
    exec ${vncdoWrapper} key ctrl-esc
    expect "Programs"
    exec ${vncdoWrapper} key up key enter
    expect "Restart"
    exec ${vncdoWrapper} key enter
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    exit 0 '';
  iso = runCommand "win98.iso" { } ''
    echo "win98-installer src: ${win98-installer}"
    mkdir win98
    ${p7zip}/bin/7z x -owin98 ${win98-installer}
    ls -lah win98
    mv win98/*.iso $out
  '';
  installedImage = runCommand "win98.img" {
    # set __impure = true; for debugging
    # __impure = true;
    buildInputs = [ p7zip dosbox-x xvfb-run x11vnc ];
    passthru = rec {
      makeRunScript = callPackage ./run.nix;
      runScript = makeRunScript { };
    };
  } ''
    echo "iso src: ${iso}"
    cp --no-preserve=mode ${iso} win98.iso
    runDosboxVnc() {
      xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" dosbox-x -conf ${dosboxConf} || true &
      dosboxPID=$!
      DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 &
    }
    runDosboxVnc
    ${expectScript} &
    expectScriptPID=$!
    wait $dosboxPID
    # Run dosbox-x a second time since it exits during the install
    runDosboxVnc
    wait $dosboxPID
    wait $expectScriptPID
    cp win98.img $out
  '';
  postInstalledImage = let
    dosboxConf-postInstall = writeText "dosbox.conf" ''
      [cpu]
      turbo=on
      stop turbo on key = false

      [autoexec]
      imgmount c win98.img
      ${dosPostInstall}
      exit
    '';
  in runCommand "win98.img" {
    buildInputs = [ dosbox-x ];
    inherit (installedImage) passthru;
  } ''
    cp --no-preserve=mode ${installedImage} ./win98.img
    SDL_VIDEODRIVER=dummy dosbox-x -conf ${dosboxConf-postInstall}
    mv win98.img $out
  '';
in if (dosPostInstall != "") then postInstalledImage else installedImage
