{ writeShellScriptBin
, openssh
, sshpass
, makeDarwinImage
, qemu_kvm
, nix
, osx-kvm
, OVMF_CODE ? "${osx-kvm}/OVMF_CODE.fd"
, OVMF_VARS ? "${osx-kvm}/OVMF_VARS-1920x1080.fd"
, OpenCoreBoot ? "${osx-kvm}/OpenCore/OpenCore.qcow2"
, threads ? 4
, cores ? 2
, sockets ? 1
, sshListenAddr ? "127.0.0.1"
, sshPort ? 2222
, mem ? "6G"
, diskImage ? (makeDarwinImage {})
, extraQemuFlags ? []
, installNix ? true
, darwinConfig ? null
, lib
, writeShellScript
}: let
  darwinSystemDrv = builtins.unsafeDiscardOutputDependency darwinConfig.system.drvPath;
  installNixRemotelyScript = writeShellScript "install-nix.sh" ''
      if ! command -v nix &> /dev/null
      then
        echo "Nix not found, installing it..."
        echo admin | sudo -S /bin/sh -c "curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm"
      fi
  '';
  installNixDarwinScript = writeShellScript "install-nix.sh" ''
    DARWIN_CONFIG="$(nix build ${darwinSystemDrv}^out --print-out-paths --no-link)"
    echo admin | sudo -S rm /etc/nix/nix.conf
    echo admin | sudo -S $DARWIN_CONFIG/activate-user
    echo admin | sudo -S $DARWIN_CONFIG/activate
  '';
  installNixScript = writeShellScript "install-nix.sh" ''
    PATH=$PATH:${openssh}/bin:${sshpass}/bin
    KEY_PATH=".ssh/id_ed25519"
    [ ! -f $KEY_PATH ] && ssh-keygen -t ed25519 -f $KEY_PATH -N ""

    while ! ssh-keyscan -p ${toString sshPort} 127.0.0.1
    do
      sleep 3
      echo SSH not ready
    done

    echo "SSH ready"

    sshpass -p admin ssh-copy-id -i $KEY_PATH -p ${toString sshPort} -o "StrictHostKeyChecking no" admin@127.0.0.1

    ssh -p ${toString sshPort} -o "StrictHostKeyChecking no" -i $KEY_PATH admin@127.0.0.1 bash -s -- < ${installNixRemotelyScript}

    ${lib.optionalString (! isNull darwinConfig) ''
      NIX_SSHOPTS="-p ${toString sshPort} -i $KEY_PATH" nix-copy-closure --to admin@127.0.0.1 ${darwinSystemDrv}

      ssh -p ${toString sshPort} -o "StrictHostKeyChecking no" -i $KEY_PATH admin@127.0.0.1 bash -s -- < ${installNixDarwinScript}
    ''}
  '';
in writeShellScriptBin "run-macOS.sh" ''
  MY_OPTIONS="+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check"

  # In case Nix is not on the path, add it, but make it lower precedence than
  # the Nix on the path
  PATH=$PATH:${nix}/bin

  args=(
    -enable-kvm -m "${mem}" -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
    -machine q35
    -usb -device usb-kbd -device usb-tablet -device usb-tablet
    -smp "${toString threads}",cores="${toString cores}",sockets="${toString sockets}"
    -device usb-ehci,id=ehci
    -device nec-usb-xhci,id=xhci
    -global nec-usb-xhci.msi=off
    -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
    -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}"
    -drive if=pflash,format=raw,readonly=on,file="${OVMF_VARS}"
    -smbios type=2
    -device ich9-intel-hda -device hda-duplex
    -drive id=OpenCoreBoot,if=virtio,snapshot=on,readonly=on,format=qcow2,file="${OpenCoreBoot}"
    -drive id=MacHDD,if=virtio,file="macos-ventura.qcow2",format=qcow2
    -netdev user,id=net0,hostfwd=tcp:${sshListenAddr}:${toString sshPort}-:22 -device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27
    #-monitor stdio
    -device virtio-vga
    ${lib.concatStringsSep " " extraQemuFlags}
    "$@"
  )

  if [ ! -f macos-ventura.qcow2 ]; then
    echo "macos-ventura.qcow2 not found, making disk image ./macos-ventura.qcow2"
    nix-store --realise ${diskImage} --add-root ./macos-ventura-base-image.qcow2
    ${qemu_kvm}/bin/qemu-img create -b ${diskImage} -F qcow2 -f qcow2 ./macos-ventura.qcow2
  fi

  ${lib.optionalString installNix "${installNixScript}&"}

  # Sometimes plugins like JACK will not be compatible with QEMU from this
  # flake, so unset LD_LIBRARY_PATH
  set -x
  unset LD_LIBRARY_PATH
  ${qemu_kvm}/bin/qemu-system-x86_64 "''${args[@]}"
''
