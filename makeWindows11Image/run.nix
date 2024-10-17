{ writeShellScriptBin
, makeWindows11Image
, qemu_kvm
, OVMF
, nix
, threads ? 4
, cores ? 2
, sockets ? 1
, mem ? "4G"
, diskImage ? (makeWindows11Image {})
, extraQemuFlags ? []
, lib
}:
writeShellScriptBin "run-win11.sh" ''
  MY_OPTIONS="+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check"

  # In case Nix is not on the path, add it, but make it lower precedence than
  # the Nix on the path
  PATH=$PATH:${nix}/bin

  args=(
    -enable-kvm -m "${mem}" -cpu host,kvm=on,+hypervisor,+invtsc,l3-cache=on,migratable=no,hv_passthrough
    -global kvm-pit.lost_tick_policy=discard -global ICH9-LPC.disable_s3=1
    -machine q35,hpet=off
    -bios ${OVMF.fd}/FV/OVMF.fd
    -usb -device usb-kbd -device usb-tablet -device usb-tablet
    -smp "${toString threads}",cores="${toString cores}",sockets="${toString sockets}"
    -device usb-ehci,id=ehci
    -device nec-usb-xhci,id=xhci
    -global nec-usb-xhci.msi=off
    -smbios type=2
    -device ich9-intel-hda -device hda-duplex
    -drive id=WinHDD,if=virtio,file="win11.qcow2",format=qcow2
    -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0,id=net0,mac=52:54:00:c9:18:27
    #-monitor stdio
    -device virtio-vga
    ${lib.concatStringsSep " " extraQemuFlags}
    "$@"
  )

  if [ ! -f win11.qcow2 ]; then
    echo "win11.qcow2 not found, making disk image ./win11.qcow2"
    nix-store --realise ${diskImage} --add-root ./win11-base-image.qcow2
    ${qemu_kvm}/bin/qemu-img create -b ${diskImage} -F qcow2 -f qcow2 ./win11.qcow2
  fi

  # Sometimes plugins like JACK will not be compatible with QEMU from this
  # flake, so unset LD_LIBRARY_PATH
  unset LD_LIBRARY_PATH
  ${qemu_kvm}/bin/qemu-system-x86_64 "''${args[@]}"
''
